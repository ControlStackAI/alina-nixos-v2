# TOOLS.md - AERO

## Aero DB Generator Pipeline
- **Repo:** ControlStackAI/aero-db-generator
- **Solvers:** AVL 3.40b, VSPAERO 3.48.2
- **Docker images:** `us-west1-docker.pkg.dev/gen-lang-client-0346823735/aero-solvers/`
  - `avl:3.40b`, `aero-worker:latest`, `vspaero:3.48.2`
- **GCP:** Cloud Run Job (`aero-solver`), GCS bucket (`aero-db-results-*`)
- **Rule:** ALWAYS use `--compute cloud_run` for >1000 cases

## Key Reference Values (King Air A90)
- Sref=282 ft², cbar=6.147 ft, bspan=45.875 ft
- Xref=15.037 ft, AR=7.46
- CD0=0.028, e_oswald=0.82

## Known Issues
- NACA 5-digit airfoil CL0 is wrong in AVL — derivatives are correct
- Use derivative-based buildup as workaround
