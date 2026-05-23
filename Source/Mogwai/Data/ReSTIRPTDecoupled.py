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
dict['PT']={'samplesPerPixel': 1,'CVMode':ReSTIRCVMode.Decoupled,"useDirectLighting":False}
dict['DI']={'CVMode':CVMode.Disable}

methodName="decoupled"
outputDir=arguments.outputDir
m.addGraph(render_graph_ReSTIRPT(dict))
if not os.path.exists(outputDir):
    os.makedirs(outputDir)
arguments.scene_setup(m)
script(m, arguments.scene_view, arguments.case_name,outputDir,methodName)
exit()
