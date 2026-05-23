from falcor import *
import os


loadRenderPassLibrary("AccumulatePass.dll")
loadRenderPassLibrary("GBuffer.dll")
loadRenderPassLibrary("ReSTIRPTPass.dll")
loadRenderPassLibrary("ToneMapper.dll")
loadRenderPassLibrary("ScreenSpaceReSTIRPass.dll")


def render_graph_ReSTIRPT(settings, isReference=False):
    g = RenderGraph("ReSTIRPTPass")

    restir_pt = createPass("ReSTIRPTPass", settings["PT"])
    g.addPass(restir_pt, "ReSTIRPTPass")

    vbuffer = createPass(
        "VBufferRT",
        {"samplePattern": SamplePattern.Center, "sampleCount": 1, "texLOD": TexLODMode.Mip0, "useAlphaTest": True},
    )
    g.addPass(vbuffer, "VBufferRT")

    accumulate = createPass("AccumulatePass", {"enabled": isReference, "precisionMode": AccumulatePrecision.Double})
    g.addPass(accumulate, "AccumulatePass")

    tonemapper = createPass("ToneMapper", {"exposureCompensation": settings["figure_exposure_ev"], "operator": ToneMapOp.Linear})
    g.addPass(tonemapper, "ToneMapper")

    screen_space_restir = createPass("ScreenSpaceReSTIRPass", settings["DI"])
    g.addPass(screen_space_restir, "ScreenSpaceReSTIRPass")

    g.addEdge("VBufferRT.vbuffer", "ReSTIRPTPass.vbuffer")
    g.addEdge("VBufferRT.mvec", "ReSTIRPTPass.motionVectors")
    g.addEdge("VBufferRT.vbuffer", "ScreenSpaceReSTIRPass.vbuffer")
    g.addEdge("VBufferRT.mvec", "ScreenSpaceReSTIRPass.motionVectors")
    g.addEdge("ScreenSpaceReSTIRPass.color", "ReSTIRPTPass.directLighting")
    g.addEdge("ReSTIRPTPass.color", "AccumulatePass.input")
    g.addEdge("AccumulatePass.output", "ToneMapper.src")

    g.markOutput("ToneMapper.dst")
    for output in settings["outputs"]:
        g.markOutput(output)

    return g


def script(m, scene_view, case_name, outputDir, methodName, isReference=False, target_frame=0, start_anim_time=0):
    m.clock.pause()
    m.clock.timeScale = 1.0

    fixed_time_step = 1.0 / 30.0
    capture_time = start_anim_time + target_frame * fixed_time_step
    m.clock.time = capture_time

    method_subdir = os.path.join(outputDir, methodName)
    os.makedirs(method_subdir, exist_ok=True)
    m.frameCapture.outputDir = method_subdir

    warmup_frames = int(os.environ.get("RESTIR_PT_WARMUP_FRAMES", "8"))
    for _ in range(warmup_frames):
        m.renderFrame()

    if isReference:
        spp = int(os.environ.get("RESTIR_PT_REFERENCE_SPP", "2048"))
        for _ in range(spp):
            m.renderFrame()
    else:
        m.renderFrame()

    filename = f"{methodName}-{case_name}-{target_frame:04d}"
    m.frameCapture.baseFilename = filename
    m.frameCapture.capture()
    print(f"Saved {filename}.*.exr to {method_subdir}")
