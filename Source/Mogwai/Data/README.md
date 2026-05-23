# ReSTIR PT Experiment Scripts

This directory contains the public Mogwai scripts for showcasing the ReSTIR PT control-variate implementation.

## Core render scripts

- `PT.py`: low-sample path-tracing sanity baseline without reuse.
- `ReSTIRPTBase.py`: ReSTIR PT baseline without control variates.
- `ReSTIRPTCV.py`: ReSTCV, the main control-variate method (`ReSTIRCVMode.ReSTCV`).
- `ReSTIRPTSTCV.py`: STCV comparison branch (`ReSTIRCVMode.STCV`).
- `ReSTIRPTDemo.py`: standalone Cornell-box demo that loads `Media/TestScenes/CornellBox.pyscene`.

## Ablation and validation scripts

- `ReSTIRPTReSTCVFixedNeighbors.py`: ReSTCV with fixed small-window neighbors for comparable difference estimates.
- `ReSTIRPTReSTCVMultiUpdate.py`: ReSTCV with multiple spatial update rounds.
- `ReSTIRPTReSTCVFixedNeighborAblation.py`: fixed-neighbor ReSTCV ablation.
- `ReSTIRPTDecoupled.py`: decoupled accumulation ablation.
- `ReSTIRPTSTCVFixedNeighborsMultiUpdate.py`: STCV with fixed neighbors and multiple spatial update rounds.

## Lightweight scenes

- `scene_config/cbox`: Cornell box.
- `scene_config/cbox_bunny`: Cornell box with bunny.

Example:

```bat
cd Source\Mogwai\Data\scene_config\cbox
..\..\..\..\..\Bin\x64\Release\Mogwai.exe --script=../../ReSTIRPTCV.py
```

Set `FALCOR_MEDIA_DIR`, `RESTIR_PT_OUTPUT_DIR`, or `RESTIR_PT_DEMO_SCENE` to override default paths.
