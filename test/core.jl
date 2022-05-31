@testset "MTL" begin

@testset "devices" begin

devs = devices()
@test length(devs) > 0

dev = first(devs)
@test dev == devs[1]

if length(devs) > 1
    @test dev != devs[2]
end

compact_str = sprint(io->show(io, dev))
full_str = sprint(io->show(io, MIME"text/plain"(), dev))

@test dev.name isa String
@test dev.isLowPower isa Bool
@test dev.isRemovable isa Bool
@test dev.hasUnifiedMemory isa Bool
@test dev.registryID isa Integer
@test dev.maxTransferRate isa Integer

@test dev.recommendedMaxWorkingSetSize isa Integer
@test dev.maxThreadgroupMemoryLength isa Integer
@test dev.maxThreadsPerThreadgroup isa MTL.MtSize
@test dev.maxBufferLength isa Integer

@test dev.currentAllocatedSize isa Integer

end

@testset "compile options" begin

opts = MtlCompileOptions()

compact_str = sprint(io->show(io, opts))
full_str = sprint(io->show(io, MIME"text/plain"(), opts))

@test opts.fastMathEnabled isa Bool
val = !opts.fastMathEnabled
opts.fastMathEnabled = val
@test opts.fastMathEnabled == val

@test opts.languageVersion isa VersionNumber
opts.languageVersion = v"1.0"
@test opts.languageVersion == v"1.0"

end

@testset "libraries" begin

dev = first(devices())
opts = MtlCompileOptions()

let lib = MtlLibrary(dev, "", opts)
    @test lib.device == dev
    @test lib.label == nothing
    @test isempty(lib.functionNames)
end

metal_code = read(joinpath(@__DIR__, "dummy.metal"), String)
let lib = MtlLibrary(dev, metal_code, opts)
    @test lib.device == dev
    @test lib.label == nothing
    fns = lib.functionNames
    @test length(fns) == 2
    @test "kernel_1" in fns
    @test "kernel_2" in fns
end

binary_path = joinpath(@__DIR__, "dummy.metallib")
let lib = MtlLibraryFromFile(dev, binary_path)
    @test lib.device == dev
    @test lib.label == nothing
    fns = lib.functionNames
    @test length(fns) == 2
    @test "kernel_1" in fns
    @test "kernel_2" in fns
end

binary_code = read(binary_path)
let lib = MtlLibraryFromData(dev, binary_code)
    @test lib.device == dev
    @test lib.label == nothing
    fns = lib.functionNames
    @test length(fns) == 2
    @test "kernel_1" in fns
    @test "kernel_2" in fns

    compact_str = sprint(io->show(io, lib))
    full_str = sprint(io->show(io, MIME"text/plain"(), lib))
end

end

@testset "functions" begin

dev = first(devices())
lib = MtlLibraryFromFile(dev, joinpath(@__DIR__, "dummy.metallib"))
fun = MtlFunction(lib, "kernel_1")

compact_str = sprint(io->show(io, fun))
full_str = sprint(io->show(io, MIME"text/plain"(), fun))

@test fun.device == dev
@test fun.label == nothing
@test fun.name == "kernel_1"
@test fun.functionType == MTL.MtFunctionTypeKernel

end

@testset "events" begin

dev = first(devices())

let ev = MtlEvent(dev)
    @test ev.device == dev
    @test ev.label == nothing
end

let ev = MtlSharedEvent(dev)
    @test ev.device == dev
    @test ev.label == nothing
    @test ev.signaledValue == 0
end

end

@testset "fences" begin

dev = first(devices())

let fen = MtlFence(dev)
    @test fen.device == dev
end

end

@testset "heap" begin

dev = first(devices())

let desc = MtlHeapDescriptor()
    @test desc.type == MTL.MtHeapTypeAutomatic
    desc.type = MTL.MtHeapTypePlacement
    @test desc.type == MTL.MtHeapTypePlacement

    @test desc.size == 0
    desc.size = 1024
    @test desc.size == 1024

    @test desc.storageMode == MTL.MtStorageModePrivate
    desc.storageMode = MTL.MtStorageModeShared
    @test desc.storageMode == MTL.MtStorageModeShared

    @test desc.cpuCacheMode == MTL.MtCPUCacheModeDefaultCache
    desc.cpuCacheMode = MTL.MtCPUCacheModeWriteCombined
    @test desc.cpuCacheMode == MTL.MtCPUCacheModeWriteCombined

    @test desc.hazardTrackingMode == MTL.MtHazardTrackingModeDefault
    desc.hazardTrackingMode = MTL.MtHazardTrackingModeUntracked
    @test desc.hazardTrackingMode == MTL.MtHazardTrackingModeUntracked

    @test desc.resourceOptions == MTL.MtResourceStorageModeShared |
                                  MTL.MtResourceCPUCacheModeWriteCombined |
                                  MTL.MtResourceHazardTrackingModeUntracked
    desc.resourceOptions = MTL.MtResourceStorageModePrivate |
                           MTL.MtResourceCPUCacheModeDefaultCache |
                           MTL.MtResourceHazardTrackingModeDefault
    @test desc.resourceOptions == MTL.MtResourceStorageModePrivate |
                                  MTL.MtResourceCPUCacheModeDefaultCache |
                                  MTL.MtResourceHazardTrackingModeDefault

    # setting resource options should be reflected in individual fields
    @test desc.storageMode == MTL.MtStorageModePrivate
    @test desc.cpuCacheMode == MTL.MtCPUCacheModeDefaultCache
    @test desc.hazardTrackingMode == MTL.MtHazardTrackingModeDefault
end

desc = MtlHeapDescriptor()
desc.size = 0x4000 # TODO: use heapBufferSizeAndAlign
let heap = MtlHeap(dev, desc)
    @test heap.label == nothing

    @test heap.type == desc.type

    @test heap.size == desc.size

    # NOTE: these checks are fragile, as the heap options seems to depend on the requested size

    #=@test=# heap.storageMode == desc.storageMode

    #=@test=# heap.cpuCacheMode == desc.cpuCacheMode

    #=@test=# heap.hazardTrackingMode == desc.hazardTrackingMode

    #=@test=# heap.resourceOptions == desc.resourceOptions
end

end

@testset "buffers" begin

dev = first(devices())

buf = MtlBuffer{Int}(dev, 1)

@test buf.length == 8

# MtlResource properties
@test buf.device == dev
@test buf.label == nothing

@test sizeof(buf) == 8

free(buf)

end

@testset "command queue" begin

dev = first(devices())

cmdq = MtlCommandQueue(dev)

@test cmdq.device == dev
@test cmdq.label == nothing

end

@testset "command buffer" begin

dev = first(devices())
cmdq = MtlCommandQueue(dev)

cmdbuf = MtlCommandBuffer(cmdq)

@test cmdbuf.device == dev
@test cmdbuf.commandQueue == cmdq
@test cmdbuf.label == nothing
@test cmdbuf.error === nothing
@test cmdbuf.status == MTL.MtCommandBufferStatusNotEnqueued
@test cmdbuf.kernelStartTime == 0
@test cmdbuf.kernelEndTime == 0
@test cmdbuf.gpuStartTime == 0
@test cmdbuf.gpuEndTime == 0

let ev = MtlSharedEvent(dev)
    @test ev.signaledValue == 0
    encode_signal!(cmdbuf, ev, 42)
    encode_wait!(cmdbuf, ev, 21)
    commit!(cmdbuf)
    wait_completed(cmdbuf)
    @test ev.signaledValue == 42
end

cmdbuf = MtlCommandBuffer(cmdq)
@test cmdbuf.status == MTL.MtCommandBufferStatusNotEnqueued
enqueue!(cmdbuf)
@test cmdbuf.status == MTL.MtCommandBufferStatusEnqueued
commit!(cmdbuf)
@test cmdbuf.status == MTL.MtCommandBufferStatusCommitted
# Completion happens too quickly to test for committed status to be checked
wait_completed(cmdbuf) == MTL.MtCommandBufferStatusCompleted
@test cmdbuf.status == MTL.MtCommandBufferStatusCompleted

# CommandBufferDescriptor tests
desc = MTL.mtNewCommandBufferDescriptor()
@test MTL.mtCommandBufferDescriptorRetainedReferences(desc) == true
MTL.mtCommandBufferDescriptorRetainedReferencesSet(desc,false)
@test MTL.mtCommandBufferDescriptorRetainedReferences(desc) == false

@test MTL.mtCommandBufferDescriptorErrorOptions(desc) == MTL.MtCommandBufferErrorOptionNone
MTL.mtCommandBufferDescriptorErrorOptionsSet(desc,MTL.MtCommandBufferErrorOptionEncoderExecutionStatus)
@test MTL.mtCommandBufferDescriptorErrorOptions(desc) == MTL.MtCommandBufferErrorOptionEncoderExecutionStatus

cmq = MtlCommandQueue(current_device())
cmdbuf = MtlCommandBuffer(cmq; retainReferences=false, errorOption=MTL.MtCommandBufferErrorOptionEncoderExecutionStatus)
@test cmdbuf.retainedReferences == false
@test cmdbuf.errorOptions == MTL.MtCommandBufferErrorOptionEncoderExecutionStatus

end

@testset "compute pipeline" begin

dev = first(devices())
lib = MtlLibraryFromFile(dev, joinpath(@__DIR__, "dummy.metallib"))
fun = MtlFunction(lib, "kernel_1")

pipeline = MtlComputePipelineState(dev, fun)

@test pipeline.device == dev
@test pipeline.label === nothing

@test pipeline.maxTotalThreadsPerThreadgroup isa Integer
@test pipeline.threadExecutionWidth isa Integer
@test pipeline.staticThreadgroupMemoryLength == 0

end

@testset "argument encoder" begin

dev = first(devices())
lib = MtlLibraryFromFile(dev, joinpath(@__DIR__, "vadd.metallib"))
fun = MtlFunction(lib, "vadd")

encoder = MtlArgumentEncoder(fun, 1)

@test encoder.encodedLength == 0
@test encoder.alignment == 1

# TODO: actually encode arguments

end

# TODO: continue adding tests

end