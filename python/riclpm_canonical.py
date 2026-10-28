"""
Table 9: random-intercept cross-lagged panel model (Hamaker, Kuiper, & Grasman, 2015).

Canonical specification: random intercepts for perceived risk (x) and the
behavior (y); within-person components with lagged paths held equal over time;
within-wave residual covariances; random intercepts uncorrelated with the
wave-1 within-person components. Behaviors are treated as continuous.

Requirements: Python 3.9+, pandas, numpy, semopy (pip install semopy).
Run from the python/ folder:  python riclpm_canonical.py
Writes ../output/table9_riclpm.json and prints the Table 9 values.

Expected (three waves, 2022 to 2024, N = 1,885):
  between-person r  .30 / .24 / .33  (relocation / property / insurance)
  perception -> behavior  .011 / -.026 / -.005, none significant at .05
  behavior -> perception  .034 / -.115 / -.033, none significant at .05
Four-wave check (2021 to 2024, N = 989): r .30 / .16 / .34; reverse path for
relocation b = .14, p = .009.
"""
import json, os, warnings
warnings.filterwarnings("ignore")
import numpy as np, pandas as pd, semopy

HERE = os.path.dirname(os.path.abspath(__file__))
DTA = os.path.join(HERE, "..", "data", "SHED_disaster_mitigation_2021_2024.dta")
OUT = os.path.join(HERE, "..", "output")
D = pd.read_stata(DTA, convert_categoricals=False)

def spec(T):
    L = ["RIx =~ " + " + ".join(f"1*x{t}" for t in range(1, T + 1)),
         "RIy =~ " + " + ".join(f"1*y{t}" for t in range(1, T + 1))]
    for t in range(1, T + 1):
        L += [f"wx{t} =~ 1*x{t}", f"wy{t} =~ 1*y{t}", f"x{t} ~~ 0*x{t}", f"y{t} ~~ 0*y{t}"]
    for t in range(2, T + 1):
        L += [f"wx{t} ~ a*wx{t-1} + b*wy{t-1}", f"wy{t} ~ c*wx{t-1} + d*wy{t-1}"]
    for t in range(1, T + 1):
        L.append(f"wx{t} ~~ wy{t}")
    L.append("RIx ~~ RIy")
    for r in ("RIx", "RIy"):
        for w in ("wx1", "wy1"):
            L.append(f"{r} ~~ 0*{w}")
    return "\n".join(L)

def wide(years, o):
    s = D[D.year.isin(years)]
    s = s.groupby("shedid").filter(lambda g: len(g) == len(years))
    w = s.pivot(index="shedid", columns="year", values=["risk_perc", o])
    df = pd.DataFrame({f"x{i+1}": w[("risk_perc", y)].astype(float) for i, y in enumerate(years)})
    for i, y in enumerate(years):
        df[f"y{i+1}"] = w[(o, y)].astype(float)
    return df

def fit(years, o):
    df = wide(years, o)
    m = semopy.Model(spec(len(years)))
    m.fit(df, obj="MLW")
    e = m.inspect(std_est=True)
    g = lambda l, op, r: e[(e.lval == l) & (e.op == op) & (e.rval == r)].iloc[0]
    rb, c, b = g("RIx", "~~", "RIy"), g("wy2", "~", "wx1"), g("wx2", "~", "wy1")
    # Fit indices computed directly (semopy's calc_stats can fail on recent SciPy).
    S = np.cov(df[m.vars["observed"]].values.T, bias=True); p = S.shape[0]; N = len(df)
    Sig = m.calc_sigma()[0]
    F = np.log(np.linalg.det(Sig)) + np.trace(S @ np.linalg.inv(Sig)) - np.log(np.linalg.det(S)) - p
    chi = N * F; dfm = p * (p + 1) // 2 - len(m.param_vals)
    chib = N * (np.sum(np.log(np.diag(S))) - np.log(np.linalg.det(S))); dfb = p * (p - 1) // 2
    cfi = 1 - max(chi - dfm, 0) / max(chib - dfb, chi - dfm, 1e-9)
    rmsea = np.sqrt(max(chi - dfm, 0) / (dfm * (N - 1)))
    return dict(n=N, r=float(rb["Est. Std"]), r_p=float(rb["p-value"]),
                perc_to_beh=float(c["Estimate"]), perc_to_beh_p=float(c["p-value"]),
                beh_to_perc=float(b["Estimate"]), beh_to_perc_p=float(b["p-value"]),
                chi2=float(chi), df=int(dfm), cfi=float(cfi), rmsea=float(rmsea))

if __name__ == "__main__":
    res = {}
    for lab, years in [("three_wave_2022_2024", [2022, 2023, 2024]),
                       ("four_wave_2021_2024", [2021, 2022, 2023, 2024])]:
        print(f"\n{lab}")
        res[lab] = {}
        for o in ("ND4_a", "ND4_b", "ND4_c"):
            r = fit(years, o); res[lab][o] = r
            print(f"  {o}  N={r['n']}  r={r['r']:.2f} (p={r['r_p']:.4f})  "
                  f"perc->beh {r['perc_to_beh']:.3f} (p={r['perc_to_beh_p']:.3f})  "
                  f"beh->perc {r['beh_to_perc']:.3f} (p={r['beh_to_perc_p']:.3f})  "
                  f"CFI={r['cfi']:.3f} RMSEA={r['rmsea']:.3f}")
    os.makedirs(OUT, exist_ok=True)
    json.dump(res, open(os.path.join(OUT, "table9_riclpm.json"), "w"), indent=2)
