from falcor import *
import os
import arguments
from script_setting import script, render_graph_ReSTIRPT

if not hasattr(arguments, 'figure_exposure_ev'):
    figure_exposure_ev=0.0
else:
    figure_exposure_ev=arguments.figure_exposure_ev
dict={}
dict['figure_exposure_ev']=figure_exposure_ev
dict['outputs']=arguments.outputs
samplesPerPixel = 5

dict['DI']={'CVMode':CVMode.Disable}

if arguments.only_GI:
    dict['PT'] = {
    'pathSamplingMode': PathSamplingMode.PathTracing, 
    'samplesPerPixel': samplesPerPixel,
    'enableTemporalReuse': False,
    'enableSpatialReuse': False,
    'numSpatialRounds': 0,
    'CVMode': ReSTIRCVMode.Disable,
    'useDirectLighting': False
}
else:
    dict['PT'] = {
    'pathSamplingMode': PathSamplingMode.PathTracing, 
    'samplesPerPixel': samplesPerPixel,
    'enableTemporalReuse': False,
    'enableSpatialReuse': False,
    'numSpatialRounds': 0,
    'CVMode': ReSTIRCVMode.Disable,
}

methodName="PT"
outputDir=arguments.outputDir
m.addGraph(render_graph_ReSTIRPT(dict))
if not os.path.exists(outputDir):
    os.makedirs(outputDir)
arguments.scene_setup(m)
script(m, arguments.scene_view, arguments.case_name,outputDir,methodName, False, arguments.target_frame, arguments.start_anim_time)
exit()
