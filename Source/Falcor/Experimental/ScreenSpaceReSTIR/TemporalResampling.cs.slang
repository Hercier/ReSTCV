/***************************************************************************
 # Copyright (c) 2015-21, NVIDIA CORPORATION. All rights reserved.
 #
 # NVIDIA CORPORATION and its licensors retain all intellectual property
 # and proprietary rights in and to this software, related documentation
 # and any modifications thereto.  Any use, reproduction, disclosure or
 # distribution of this software and related documentation without an express
 # license agreement from NVIDIA CORPORATION is strictly prohibited.
 **************************************************************************/
import Utils.Attributes;
import Utils.Sampling.TinyUniformSampleGenerator;
import Utils.Debug.PixelDebug;
import SurfaceData;
import EvalContext;
import Lights;
import Resampling;
import Params;

/** Performs temporal resampling by combining the reservoir from the initial
    resampling pass with a reservoir from the last frame obtained through
    reprojection.
*/
struct TemporalResampling
{
    // Static configuration.
    static const uint kMaxHistoryLength = MAX_HISTORY_LENGTH;

    static const bool kUsePairwiseMIS = USE_PAIRWISE_MIS;
    static const bool kUnbiased = UNBIASED;
    static const uint kCVMode = CV_MODE;
    static const DebugOutput kDebugOutput = DebugOutput(DEBUG_OUTPUT);

    [root] StructuredBuffer<PackedSurfaceData> surfaceData;
    [root] StructuredBuffer<PackedSurfaceData> prevSurfaceData;
    Texture2D<float2> motionVectors;
    RWStructuredBuffer<PackedReservoir> reservoirs;
    StructuredBuffer<PackedReservoir> prevReservoirs;
    RWTexture2D<float4> debugOutput;

    Lights lights;

    uint2 frameDim;
    uint frameIndex;

    float normalThreshold;
    float depthThreshold;

    uint getPixelIndex(uint2 pixel) { return pixel.y * frameDim.x + pixel.x; }

    bool isValidPixel(int2 pixel) { return all(pixel >= 0 && pixel < frameDim); }

    void process(uint2 pixel)
    {
        if (any(pixel >= frameDim)) return;

        printSetPixel(pixel);
        
        if (kDebugOutput == DebugOutput::TemporalReuse) debugOutput[pixel] = float4(1.f, 0.f, 0.f, 0.f);

        const uint pixelIndex = getPixelIndex(pixel);

        TinyUniformSampleGenerator sg = TinyUniformSampleGenerator(pixel, frameIndex);

        // Back-project this pixel to previous frame.
        const int2 prevPixel = pixel + motionVectors[pixel] * frameDim + (sampleNext2D(sg) * 1.f - 0.f);
        if (!isValidPixel(prevPixel)) return;
        const uint prevPixelIndex = getPixelIndex(prevPixel);

        // Setup evaluation context for current pixel.
        const EvalContext currentContext = EvalContext::create(pixel, frameDim, SurfaceData::createFromPacked(surfaceData[pixelIndex]));
        if (!currentContext.isValid()) return;

        // Setup evaluation context for back-projected pixel.
        const EvalContext prevContext = EvalContext::createPrev(prevPixel, frameDim, SurfaceData::createFromPacked(prevSurfaceData[prevPixelIndex]));
        if (!prevContext.isValid()) return;

        // Write debug output.
        if (kDebugOutput == DebugOutput::TemporalReuse) debugOutput[pixel] = float4(0.f, 1.f, 0.f, 0.f);

        // Load reservoirs.
        Reservoir currentReservoir = Reservoir::createFromPacked(reservoirs[pixelIndex]);
        Reservoir prevReservoir = Reservoir::createFromPacked(prevReservoirs[prevPixelIndex]);
        prevReservoir.M = min(prevReservoir.M, currentReservoir.M * kMaxHistoryLength);

        // Setup resampling.
        RisState risState = RisState::createEmpty();
        bool directAccumulation = false;
        if (!currentContext.isValidNeighbor(float4(prevContext.N, prevContext.distanceToCamera()), normalThreshold, depthThreshold)) {
            return;
        }
        if (kUsePairwiseMIS)
        {
            const LoadedLightSample currentLightSample = lights.loadLightSample(currentReservoir.lightSample);
            float2 currentPdfWithBGV= currentContext.evalTargetFunctionWithBGV(currentLightSample, kUnbiased);
            streamingResampleStepMisUnbiased(risState, currentReservoir, currentLightSample, currentPdfWithBGV, currentContext, prevReservoir, prevContext, 1, lights, sg,true);
            streamingResampleFinalizeMis(risState, currentReservoir, currentPdfWithBGV.x ,sg);
            risState.weight = risState.weight > 0.f ? risState.weightSum / risState.weight : 0.f;
            if (directAccumulation) {
                risState.accumulatedContribution = currentReservoir.accumulatedContribution;
            }
            else {
                if (kCVMode) {
                    risState.accumulatedContribution = risState.accumulatedContribution / risState.M;
                }
                if (kCVMode == 2) {
                    risState.weight=currentReservoir.weight;
                    risState.lightSample=currentReservoir.lightSample;
                }
            }
            // print("M: ", risState.M);
            // print("Weight: ", risState.weight);
            // print("Accumulated Contribution: ", risState.accumulatedContribution);
        }
        else
        {
            // Check if previous sample is valid for reuse.

            // Resample current and previous reservoirs.
            streamingResampleStep(risState, currentReservoir, currentContext, lights, sg);
            bool usedPrev = streamingResampleStep(risState, prevReservoir, currentContext, lights, sg);
            print("Alpha",currentContext.ggxAlpha);
            // Compute the unbiased normalization term (instead of using 1/M).
            const LoadedLightSample lightSample = lights.loadLightSample(risState.lightSample);
            float2 pdfwithBGV= currentContext.evalTargetFunctionWithBGV(lightSample, kUnbiased);
            float currentPdf = pdfwithBGV.x;
            float prevPdf = prevContext.evalTargetFunction(lightSample, kUnbiased); 
            float weightprev = prevPdf / (currentReservoir.M * currentPdf + prevReservoir.M * prevPdf);
            float weightcurrent = currentPdf / (currentReservoir.M * currentPdf + prevReservoir.M * prevPdf);
            float normalization = usedPrev ? weightprev : weightcurrent;
            float UCW = risState.weight > 0.f ? (risState.weightSum / risState.M) / risState.weight : 0.f;
            risState.weight = risState.weight > 0.f ? (risState.weightSum * normalization) / risState.weight : 0.f;
            float3 currentRadiance = lights.evalEmission(risState.lightSample) * pdfwithBGV.y * risState.weight;
            // float3 currentRadiance = lights.evalEmission(prevReservoir.lightSample) * currentContext.evalScalarBGV(lights.loadLightSample(prevReservoir.lightSample)) * prevReservoir.weight;
            if (kCVMode) {
                risState.accumulatedContribution = currentReservoir.accumulatedContribution * currentReservoir.M+
                                                (prevReservoir.accumulatedContribution+currentRadiance) * prevReservoir.M;
                risState.accumulatedContribution /= (currentReservoir.M + prevReservoir.M);
            }
        }

        // Save reservoir.
        reservoirs[pixelIndex] = risState.toReservoir().pack();
    }
};

cbuffer CB
{
    TemporalResampling gTemporalResampling;
}

[numthreads(16, 4, 1)]
void main(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    gTemporalResampling.process(dispatchThreadId.xy);
}
