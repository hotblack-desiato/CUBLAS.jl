import Base.LinAlg.BLAS
using CUBLAS
using CUDArt
using Base.Test

m = 20
n = 35
k = 13

function blasabs(A)
    return abs.(real(A)) + abs.(imag(A))
end

#################
# level 1 tests #
#################

@testset "blascopy!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        A = convert(Vector{elty}, collect(1:m))
        if elty <: Base.LinAlg.BlasComplex
            A += im*A
        end
        @test ndims(A) == 1
        n1 = length(A)
        d_A = CudaArray(A)
        d_B = CudaArray(elty, n1)
        CUBLAS.blascopy!(n,d_A,1,d_B,1)
        B = to_host(d_B)
        @test A == B
    end
end

@testset "scal!" begin
    function test_scal!{T}(alpha,A::Array{T})
        @test ndims(A) == 1
        n1 = length(A)
        d_A = CudaArray(A)
        CUBLAS.scal!(n1,alpha,d_A,1)
        A1 = to_host(d_A)
        @test alpha*A ≈ A1

        d_A = CudaArray(A)
        d_As = CUBLAS.scale(d_A, alpha)
        A1 = to_host(d_As)
        @test alpha*A ≈ A1

        CUBLAS.scale!(d_A, alpha)
        A1 = to_host(d_As)
        @test alpha*A ≈ A1
    end
    test_scal!(2.0f0,Float32[1:m;])
    test_scal!(2.0,Float64[1:m;])
    test_scal!(1.0f0+im*1.0f0,Float32[1:m;]+im*Float32[1:m;])
    test_scal!(1.0+im*1.0,Float64[1:m;]+im*Float64[1:m;])
    test_scal!(2.0f0,Float32[1:m;]+im*Float32[1:m;])
    test_scal!(2.0,Float64[1:m;]+im*Float64[1:m;])
end

@testset "dot" begin
    @testset for elty in [Float32, Float64]
        A = convert(Vector{elty}, collect(1:m))
        B = convert(Vector{elty}, collect(1:m))
        @test ndims(A) == 1
        @test ndims(B) == 1
        @test length(A) == length(B)
        n1 = length(A)
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        cuda_dot1 = CUBLAS.dot(n1,d_A,1,d_B,1)
        cuda_dot2 = CUBLAS.dot(d_A,d_B)
        host_dot = dot(A,B)
        @test host_dot ≈ cuda_dot1
        @test host_dot ≈ cuda_dot2

        #d_A = CudaArray(A)
        #d_B = CudaArray(B)
        #cuda_dot3 = CUBLAS.dot(d_A, 3:5, d_B, 5:7)
        #host_dot3 = dot(A, 3:5, B, 5:7)
        #@test_approx_eq(cuda_dot3, host_dot3)
    end
end

@testset "dotu" begin
    @testset for elty in [Complex64, Complex128]
        A = rand(elty, m)
        B = rand(elty, m)
        @test ndims(A) == 1
        @test ndims(B) == 1
        @test length(A) == length(B)
        n1 = length(A)
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        cuda_dot1 = CUBLAS.dotu(n1,d_A,1,d_B,1)
        cuda_dot2 = CUBLAS.dotu(d_A,d_B)
        host_dot = A.'*B
        if VERSION < v"0.6.0-dev.2074" # julia PR #19670
            @test host_dot[1] ≈ cuda_dot1
            @test host_dot[1] ≈ cuda_dot2
            @test host_dot ≈ (d_A.'*d_B)
        else
            @test host_dot ≈ cuda_dot1
            @test host_dot ≈ cuda_dot2
            @test host_dot ≈ (d_A.'*d_B)[1]
        end
    end
end

@testset "dotc" begin
    @testset for elty in [Complex64, Complex128]
        A = rand(elty, m)
        B = rand(elty, m)
        @test ndims(A) == 1
        @test ndims(B) == 1
        @test length(A) == length(B)
        n1 = length(A)
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        cuda_dot1 = CUBLAS.dotc(n1,d_A,1,d_B,1)
        cuda_dot2 = CUBLAS.dotc(d_A,d_B)
        host_dot = A'*B
        if VERSION < v"0.6.0-dev.2074" # julia PR #19670
            @test host_dot[1] ≈ cuda_dot1
            @test host_dot[1] ≈ cuda_dot2
            @test host_dot ≈ (d_A'*d_B)
        else
            @test host_dot ≈ cuda_dot1
            @test host_dot ≈ cuda_dot2
            @test host_dot ≈ (d_A'*d_B)[1]
        end
    end
end

@testset "nrm2" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        A = rand(elty, m)
        @test ndims(A) == 1
        n1 = length(A)
        d_A = CudaArray(A)
        cuda_nrm2_1 = CUBLAS.nrm2(n1,d_A,1)
        cuda_nrm2_2 = CUBLAS.nrm2(d_A)
        cuda_nrm2_3 = norm(d_A)
        host_nrm2 = norm(A)
        @test host_nrm2 ≈ cuda_nrm2_1
        @test host_nrm2 ≈ cuda_nrm2_2
        @test host_nrm2 ≈ cuda_nrm2_3
    end
end

@testset "asum" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        A = rand(elty, m)
        @test ndims(A) == 1
        n1 = length(A)
        d_A = CudaArray(A)
        cuda_asum1 = CUBLAS.asum(n1,d_A,1)
        cuda_asum2 = CUBLAS.asum(d_A)
        host_asum = sum(abs.(real(A)) + abs.(imag(A)))
        @test host_asum ≈ cuda_asum1
        @test host_asum ≈ cuda_asum2
    end
end

@testset "axpy!" begin
    # test axpy!
    function test_axpy!_1(alpha,A,B)
        @test length(A) == length(B)
        n1 = length(A)
        d_A = CudaArray(A)
        d_B1 = CudaArray(B)
        CUBLAS.axpy!(n1,alpha,d_A,1,d_B1,1)
        B1 = to_host(d_B1)
        host_axpy = alpha*A + B
        @test host_axpy ≈ B1
    end
    test_axpy!_1(2.0f0,rand(Float32,m),rand(Float32,m))
    test_axpy!_1(2.0,rand(Float64,m),rand(Float64,m))
    test_axpy!_1(2.0f0+im*2.0f0,rand(Complex64,m),rand(Complex64,m))
    test_axpy!_1(2.0+im*2.0,rand(Complex128,m),rand(Complex128,m))

    function test_axpy!_2(alpha,A,B)
        @test length(A) == length(B)
        n1 = length(A)
        d_A = CudaArray(A)
        d_B1 = CudaArray(B)
        CUBLAS.axpy!(alpha,d_A,d_B1)
        B1 = to_host(d_B1)
        host_axpy = alpha*A + B
        @test host_axpy ≈ B1
    end
    test_axpy!_2(2.0f0,rand(Float32,m),rand(Float32,m))
    test_axpy!_2(2.0,rand(Float64,m),rand(Float64,m))
    test_axpy!_2(2.0f0+im*2.0f0,rand(Complex64,m),rand(Complex64,m))
    test_axpy!_2(2.0+im*2.0,rand(Complex128,m),rand(Complex128,m))

    #=function test_axpy!_3(alpha,A,B)
        @test length(A) == length(B)
        n1 = length(A)
        d_A = CudaArray(A)
        d_B1 = CudaArray(B)
        CUBLAS.axpy!(alpha,d_A,1:2:n1,d_B1,1:2:n1)
        B1 = to_host(d_B1)
        host_axpy = B
        host_axpy[1:2:n1] = alpha*A[1:2:n1] + B[1:2:n1]
        @test_approx_eq(host_axpy,B1)
    end
    test_axpy!_3(2.0f0,rand(Float32,m),rand(Float32,m))
    test_axpy!_3(2.0,rand(Float64,m),rand(Float64,m))
    test_axpy!_3(2.0f0+im*2.0f0,rand(Complex64,m),rand(Complex64,m))
    test_axpy!_3(2.0+im*2.0,rand(Complex128,m),rand(Complex128,m))

    function test_axpy!_4(alpha,A,B)
        @test length(A) == length(B)
        n1 = length(A)
        d_A = CudaArray(A)
        d_B1 = CudaArray(B)
        r = 1:div(n1,2)
        CUBLAS.axpy!(alpha,d_A,r,d_B1,r)
        B1 = to_host(d_B1)
        host_axpy = B
        host_axpy[r] = alpha*A[r] + B[r]
        @test_approx_eq(host_axpy,B1)
    end
    test_axpy!_4(2.0f0,rand(Float32,m),rand(Float32,m))
    test_axpy!_4(2.0,rand(Float64,m),rand(Float64,m))
    test_axpy!_4(2.0f0+im*2.0f0,rand(Complex64,m),rand(Complex64,m))
    test_axpy!_4(2.0+im*2.0,rand(Complex128,m),rand(Complex128,m))=#
end

@testset "iamax and iamin" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        A = rand(elty, m)
        n1 = length(A)
        d_A = CudaArray(A)
        Aabs = blasabs(A)
        imin1 = CUBLAS.iamin(n1,d_A,1)
        imax1 = CUBLAS.iamax(n1,d_A,1)
        imin2 = CUBLAS.iamin(d_A)
        imax2 = CUBLAS.iamax(d_A)
        host_imin = indmin(Aabs)
        host_imax = indmax(Aabs)
        @test imin1 == imin2 == host_imin
        @test imin1 == imin2 == host_imin
    end
end

#################
# level 2 tests #
#################

@testset "gemv!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        alpha = convert(elty,1)
        beta = convert(elty,1)
        A = rand(elty,m,n)
        d_A = CudaArray(A)

        # test y = A*x + y
        x = rand(elty,n)
        d_x = CudaArray(x)
        y = rand(elty,m)
        d_y = CudaArray(y)
        y = A*x + y
        CUBLAS.gemv!('N',alpha,d_A,d_x,beta,d_y)
        h_y = to_host(d_y)
        @test y ≈ h_y
        A_mul_B!(d_y,d_A,d_x)
        h_y = to_host(d_y)
        @test h_y ≈ A*x

        # test x = A.'*y + x
        x = rand(elty,n)
        d_x = CudaArray(x)
        y = rand(elty,m)
        d_y = CudaArray(y)
        x = A.'*y + x
        CUBLAS.gemv!('T',alpha,d_A,d_y,beta,d_x)
        h_x = to_host(d_x)
        @test x ≈ h_x
        At_mul_B!(d_x,d_A,d_y)
        h_x = to_host(d_x)
        @test h_x ≈ A.'*y

        # test x = A'*y + x
        x = rand(elty,n)
        d_x = CudaArray(x)
        y = rand(elty,m)
        d_y = CudaArray(y)
        x = A'*y + x
        CUBLAS.gemv!('C',alpha,d_A,d_y,beta,d_x)
        h_x = to_host(d_x)
        @test x ≈ h_x
        Ac_mul_B!(d_x,d_A,d_y)
        h_x = to_host(d_x)
        @test h_x ≈ A'*y
    end
end

@testset "gemv" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        alpha = convert(elty,2)
        A = rand(elty,m,n)
        d_A = CudaArray(A)
        # test y = alpha*(A*x)
        x = rand(elty,n)
        d_x = CudaArray(x)
        y1 = alpha*(A*x)
        y2 = A*x
        d_y1 = CUBLAS.gemv('N',alpha,d_A,d_x)
        d_y2 = CUBLAS.gemv('N',d_A,d_x)
        h_y1 = to_host(d_y1)
        h_y2 = to_host(d_y2)
        @test y1 ≈ h_y1
        @test y2 ≈ h_y2
        @test y2 ≈ to_host(d_A * d_x)

        # test x = alpha*(A.'*y)
        y = rand(elty,m)
        d_y = CudaArray(y)
        x1 = alpha*(A.'*y)
        x2 = A.'*y
        d_x1 = CUBLAS.gemv('T',alpha,d_A,d_y)
        d_x2 = CUBLAS.gemv('T',d_A,d_y)
        h_x1 = to_host(d_x1)
        h_x2 = to_host(d_x2)
        @test x1 ≈ h_x1
        @test x2 ≈ h_x2
        @test x2 ≈ to_host(d_A.' * d_y)

        # test x = alpha*(A'*y)
        y = rand(elty,m)
        d_y = CudaArray(y)
        x1 = alpha*(A'*y)
        x2 = A'*y
        d_x1 = CUBLAS.gemv('C',alpha,d_A,d_y)
        d_x2 = CUBLAS.gemv('C',d_A,d_y)
        h_x1 = to_host(d_x1)
        h_x2 = to_host(d_x2)
        @test y1 ≈ h_y1
        @test y2 ≈ h_y2
        @test x2 ≈ to_host(d_A' * d_y)
    end
end

@testset "gbmv!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # parameters
        alpha = convert(elty,2)
        beta = convert(elty,3)
        # bands
        ku = 2
        kl = 3
        # generate banded matrix
        A = rand(elty,m,n)
        A = bandex(A,kl,ku)
        # get packed format
        Ab = band(A,kl,ku)
        d_Ab = CudaArray(Ab)
        # test y = alpha*A*x + beta*y
        x = rand(elty,n)
        d_x = CudaArray(x)
        y = rand(elty,m)
        d_y = CudaArray(y)
        CUBLAS.gbmv!('N',m,kl,ku,alpha,d_Ab,d_x,beta,d_y)
        BLAS.gbmv!('N',m,kl,ku,alpha,Ab,x,beta,y)
        h_y = to_host(d_y)
        @test y ≈ h_y
        # test y = alpha*A.'*x + beta*y
        x = rand(elty,n)
        d_x = CudaArray(x)
        y = rand(elty,m)
        d_y = CudaArray(y)
        CUBLAS.gbmv!('T',m,kl,ku,alpha,d_Ab,d_y,beta,d_x)
        BLAS.gbmv!('T',m,kl,ku,alpha,Ab,y,beta,x)
        h_x = to_host(d_x)
        @test x ≈ h_x
        # test y = alpha*A'*x + beta*y
        x = rand(elty,n)
        d_x = CudaArray(x)
        y = rand(elty,m)
        d_y = CudaArray(y)
        CUBLAS.gbmv!('C',m,kl,ku,alpha,d_Ab,d_y,beta,d_x)
        BLAS.gbmv!('C',m,kl,ku,alpha,Ab,y,beta,x)
        h_x = to_host(d_x)
        @test x ≈ h_x
    end
end

@testset "gbmv" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # parameters
        alpha = convert(elty,2)
        # bands
        ku = 2
        kl = 3
        # generate banded matrix
        A = rand(elty,m,n)
        A = bandex(A,kl,ku)
        # get packed format
        Ab = band(A,kl,ku)
        d_Ab = CudaArray(Ab)
        # test y = alpha*A*x
        x = rand(elty,n)
        d_x = CudaArray(x)
        d_y = CUBLAS.gbmv('N',m,kl,ku,alpha,d_Ab,d_x)
        y = zeros(elty,m)
        y = BLAS.gbmv('N',m,kl,ku,alpha,Ab,x)
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "symv!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # parameters
        alpha = convert(elty,2)
        beta = convert(elty,3)
        # generate symmetric matrix
        A = rand(elty,m,m)
        A = A + A.'
        # generate vectors
        x = rand(elty,m)
        y = rand(elty,m)
        # copy to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        d_y = CudaArray(y)
        # execute on host
        BLAS.symv!('U',alpha,A,x,beta,y)
        # execute on device
        CUBLAS.symv!('U',alpha,d_A,d_x,beta,d_y)
        # compare results
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "symv" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate symmetric matrix
        A = rand(elty,m,m)
        A = A + A.'
        # generate vectors
        x = rand(elty,m)
        # copy to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        # execute on host
        y = BLAS.symv('U',A,x)
        # execute on device
        d_y = CUBLAS.symv('U',d_A,d_x)
        # compare results
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "hemv!" begin
    @testset for elty in [Complex64, Complex128]
        # parameters
        alpha = convert(elty,2)
        beta = convert(elty,3)
        # generate hermitian matrix
        A = rand(elty,m,m)
        A = A + A'
        # generate vectors
        x = rand(elty,m)
        y = rand(elty,m)
        # copy to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        d_y = CudaArray(y)
        # execute on host
        BLAS.hemv!('U',alpha,A,x,beta,y)
        # execute on device
        CUBLAS.hemv!('U',alpha,d_A,d_x,beta,d_y)
        # compare results
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "hemv" begin
    @testset for elty in [Complex64, Complex128]
        # generate hermitian matrix
        A = rand(elty,m,m)
        A = A + A.'
        # generate vectors
        x = rand(elty,m)
        # copy to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        # execute on host
        y = BLAS.hemv('U',A,x)
        # execute on device
        d_y = CUBLAS.hemv('U',d_A,d_x)
        # compare results
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "sbmv!" begin
    @testset for elty in [Float32, Float64]
        # parameters
        alpha = convert(elty,3)
        beta = convert(elty,2.5)
        # generate symmetric matrix
        A = rand(elty,m,m)
        A = A + A'
        # restrict to 3 bands
        nbands = 3
        @test m >= 1+nbands
        A = bandex(A,nbands,nbands)
        # convert to 'upper' banded storage format
        AB = band(A,0,nbands)
        # construct x and y
        x = rand(elty,m)
        y = rand(elty,m)
        # move to host
        d_AB = CudaArray(AB)
        d_x = CudaArray(x)
        d_y = CudaArray(y)
        # sbmv!
        CUBLAS.sbmv!('U',nbands,alpha,d_AB,d_x,beta,d_y)
        y = alpha*(A*x) + beta*y
        # compare
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "sbmv" begin
    @testset for elty in [Float32, Float64]
        # parameters
        alpha = convert(elty,3)
        beta = convert(elty,2.5)
        # generate symmetric matrix
        A = rand(elty,m,m)
        A = A + A'
        # restrict to 3 bands
        nbands = 3
        @test m >= 1+nbands
        A = bandex(A,nbands,nbands)
        # convert to 'upper' banded storage format
        AB = band(A,0,nbands)
        # construct x and y
        x = rand(elty,m)
        y = rand(elty,m)
        # move to host
        d_AB = CudaArray(AB)
        d_x = CudaArray(x)
        # sbmv!
        d_y = CUBLAS.sbmv('U',nbands,d_AB,d_x)
        y = A*x
        # compare
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "hbmv!" begin
    @testset for elty in [Complex64, Complex128]
        # parameters
        alpha = rand(elty)
        beta = rand(elty)
        # generate Hermitian matrix
        A = rand(elty,m,m)
        A = A + ctranspose(A)
        # restrict to 3 bands
        nbands = 3
        @test m >= 1+nbands
        A = bandex(A,nbands,nbands)
        # convert to 'upper' banded storage format
        AB = band(A,0,nbands)
        # construct x and y
        x = rand(elty,m)
        y = rand(elty,m)
        # move to host
        d_AB = CudaArray(AB)
        d_x = CudaArray(x)
        d_y = CudaArray(y)
        # hbmv!
        CUBLAS.hbmv!('U',nbands,alpha,d_AB,d_x,beta,d_y)
        y = alpha*(A*x) + beta*y
        # compare
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "hbmv" begin
    @testset for elty in [Complex64, Complex128]
        # parameters
        alpha = rand(elty)
        beta = rand(elty)
        # generate Hermitian matrix
        A = rand(elty,m,m)
        A = A + ctranspose(A)
        # restrict to 3 bands
        nbands = 3
        @test m >= 1+nbands
        A = bandex(A,nbands,nbands)
        # convert to 'upper' banded storage format
        AB = band(A,0,nbands)
        # construct x and y
        x = rand(elty,m)
        y = rand(elty,m)
        # move to host
        d_AB = CudaArray(AB)
        d_x = CudaArray(x)
        # hbmv
        d_y = CUBLAS.hbmv('U',nbands,d_AB,d_x)
        y = A*x
        # compare
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "tbmv!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate triangular matrix
        A = rand(elty,m,m)
        # restrict to 3 bands
        nbands = 3
        @test m >= 1+nbands
        A = bandex(A,0,nbands)
        # convert to 'upper' banded storage format
        AB = band(A,0,nbands)
        # construct x and y
        x = rand(elty,m)
        # move to host
        d_AB = CudaArray(AB)
        d_x = CudaArray(x)
        # tbmv!
        CUBLAS.tbmv!('U','N','N',nbands,d_AB,d_x)
        x = A*x
        # compare
        h_x = to_host(d_x)
        @test x ≈ h_x
    end
end

@testset "tbmv" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate triangular matrix
        A = rand(elty,m,m)
        # restrict to 3 bands
        nbands = 3
        @test m >= 1+nbands
        A = bandex(A,0,nbands)
        # convert to 'upper' banded storage format
        AB = band(A,0,nbands)
        # construct x
        x = rand(elty,m)
        # move to host
        d_AB = CudaArray(AB)
        d_x = CudaArray(x)
        # tbmv!
        d_y = CUBLAS.tbmv!('U','N','N',nbands,d_AB,d_x)
        y = A*x
        # compare
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "tbsv!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate triangular matrix
        A = rand(elty,m,m)
        # restrict to 3 bands
        nbands = 3
        @test m >= 1+nbands
        A = bandex(A,0,nbands)
        # convert to 'upper' banded storage format
        AB = band(A,0,nbands)
        # generate vector
        x = rand(elty,m)
        # move to device
        d_AB = CudaArray(AB)
        d_x = CudaArray(x)
        #tbsv!
        CUBLAS.tbsv!('U','N','N',nbands,d_AB,d_x)
        x = A\x
        # compare
        h_x = to_host(d_x)
        @test x ≈ h_x
    end
end

@testset "tbsv" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate triangular matrix
        A = rand(elty,m,m)
        # restrict to 3 bands
        nbands = 3
        @test m >= 1+nbands
        A = bandex(A,0,nbands)
        # convert to 'upper' banded storage format
        AB = band(A,0,nbands)
        # generate vector
        x = rand(elty,m)
        # move to device
        d_AB = CudaArray(AB)
        d_x = CudaArray(x)
        #tbsv
        d_y = CUBLAS.tbsv('U','N','N',nbands,d_AB,d_x)
        y = A\x
        # compare
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "trmv!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate triangular matrix
        A = rand(elty,m,m)
        A = triu(A)
        # generate vector
        x = rand(elty,m)
        # move to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        # execute trmv!
        CUBLAS.trmv!('U','N','N',d_A,d_x)
        x = A*x
        # compare
        h_x = to_host(d_x)
        @test x ≈ h_x
    end
end

@testset "trmv" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate triangular matrix
        A = rand(elty,m,m)
        A = triu(A)
        # generate vector
        x = rand(elty,m)
        # move to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        # execute trmv!
        d_y = CUBLAS.trmv('U','N','N',d_A,d_x)
        y = A*x
        # compare
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "trsv!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate triangular matrix
        A = rand(elty,m,m)
        A = triu(A)
        # generate vector
        x = rand(elty,m)
        # move to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        # execute trsv!
        CUBLAS.trsv!('U','N','N',d_A,d_x)
        x = A\x
        # compare
        h_x = to_host(d_x)
        @test x ≈ h_x
    end
end

@testset "trsv" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate triangular matrix
        A = rand(elty,m,m)
        A = triu(A)
        # generate vector
        x = rand(elty,m)
        # move to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        # execute trsv!
        d_y = CUBLAS.trsv('U','N','N',d_A,d_x)
        y = A\x
        # compare
        h_y = to_host(d_y)
        @test y ≈ h_y
    end
end

@testset "ger!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # construct matrix and vectors
        A = rand(elty,m,n)
        x = rand(elty,m)
        y = rand(elty,n)
        alpha = convert(elty,2)
        # move to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        d_y = CudaArray(y)
        # perform rank one update
        CUBLAS.ger!(alpha,d_x,d_y,d_A)
        A = (alpha*x)*y' + A
        # move to host and compare
        h_A = to_host(d_A)
        @test A ≈ h_A
    end
end

@testset "syr!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # construct matrix and vector
        A = rand(elty,m,m)
        A = A + A.'
        x = rand(elty,m)
        alpha = convert(elty,2)
        # move to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        # perform rank one update
        CUBLAS.syr!('U',alpha,d_x,d_A)
        A = (alpha*x)*x.' + A
        # move to host and compare upper triangles
        h_A = to_host(d_A)
        A = triu(A)
        h_A = triu(h_A)
        @test A ≈ h_A
    end
end

@testset "her!" begin
    @testset for elty in [Complex64, Complex128]
        local m = 2
        # construct matrix and vector
        A = rand(elty,m,m)
        A = A + A'
        x = rand(elty,m)
        alpha = convert(elty,2)
        # move to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        # perform rank one update
        CUBLAS.her!('U',alpha,d_x,d_A)
        A = (alpha*x)*x' + A
        # move to host and compare upper triangles
        h_A = to_host(d_A)
        A = triu(A)
        h_A = triu(h_A)
        @test A ≈ h_A
    end
end

@testset "her2!" begin
    @testset for elty in [Complex64, Complex128]
        local m = 2
        # construct matrix and vector
        A = rand(elty,m,m)
        A = A + A'
        x = rand(elty,m)
        y = rand(elty,m)
        alpha = convert(elty,2)
        # move to device
        d_A = CudaArray(A)
        d_x = CudaArray(x)
        d_y = CudaArray(y)
        # perform rank one update
        CUBLAS.her2!('U',alpha,d_x,d_y,d_A)
        A = (alpha*x)*y' + y*(alpha*x)' + A
        # move to host and compare upper triangles
        h_A = to_host(d_A)
        A = triu(A)
        h_A = triu(h_A)
        @test A ≈ h_A
    end
end

@testset "gemm!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # parameters
        alpha = rand(elty)
        beta = rand(elty)
        # generate matrices
        A = rand(elty,m,k)
        B = rand(elty,k,n)
        C1 = rand(elty,m,n)
        C2 = copy(C1)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        d_C1 = CudaArray(C1)
        d_C2 = CudaArray(C2)
        # C = (alpha*A)*B + beta*C
        CUBLAS.gemm!('N','N',alpha,d_A,d_B,beta,d_C1)
        A_mul_B!(d_C2, d_A, d_B)
        h_C1 = to_host(d_C1)
        h_C2 = to_host(d_C2)
        C1 = (alpha*A)*B + beta*C1
        C2 = A*B
        # compare
        @test C1 ≈ h_C1
        @test C2 ≈ h_C2
    end
end

@testset "gemm" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,k)
        B = rand(elty,k,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        # C = (alpha*A)*B + beta*C
        d_C = CUBLAS.gemm('N','N',d_A,d_B)
        C = A*B
        C2 = d_A * d_B
        # compare
        h_C = to_host(d_C)
        h_C2 = to_host(C2)
        @test C ≈ h_C
        @test C ≈ h_C2
    end
end

@testset "gemm_batched!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # parameters
        alpha = rand(elty)
        beta = rand(elty)
        # generate matrices
        A = [rand(elty,m,k) for i in 1:10]
        B = [rand(elty,k,n) for i in 1:10]
        C = [rand(elty,m,n) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        d_B = CudaArray{elty, 2}[]
        d_C = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
            push!(d_B,CudaArray(B[i]))
            push!(d_C,CudaArray(C[i]))
        end
        # C = (alpha*A)*B + beta*C
        CUBLAS.gemm_batched!('N','N',alpha,d_A,d_B,beta,d_C)
        for i in 1:length(d_C)
            C[i] = (alpha*A[i])*B[i] + beta*C[i]
            h_C = to_host(d_C[i])
            #compare
            @test C[i] ≈ h_C
        end
    end
end

@testset "gemm_batched" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,m,k) for i in 1:10]
        B = [rand(elty,k,n) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        d_B = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A, CudaArray(A[i]))
            push!(d_B, CudaArray(B[i]))
        end
        # C = A*B
        d_C = CUBLAS.gemm_batched('N','N',d_A,d_B)
        for i in 1:length(A)
            C = A[i]*B[i]
            h_C = to_host(d_C[i])
            @test C ≈ h_C
        end
    end
end

@testset "symm!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # parameters
        alpha = rand(elty)
        beta = rand(elty)
        # generate matrices
        A = rand(elty,m,m)
        A = A + A.'
        B = rand(elty,m,n)
        C = rand(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        d_C = CudaArray(C)
        # C = (alpha*A)*B + beta*C
        CUBLAS.symm!('L','U',alpha,d_A,d_B,beta,d_C)
        C = (alpha*A)*B + beta*C
        # compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

@testset "symm" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,m)
        A = A + A.'
        B = rand(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        # C = (alpha*A)*B + beta*C
        d_C = CUBLAS.symm('L','U',d_A,d_B)
        C = A*B
        # compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

@testset "syrk!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,k)
        C = rand(elty,m,m)
        C = C + C.'
        # parameters
        alpha = rand(elty)
        beta = rand(elty)
        # move to device
        d_A = CudaArray(A)
        d_C = CudaArray(C)
        # C = (alpha*A)*A.' + beta*C
        CUBLAS.syrk!('U','N',alpha,d_A,beta,d_C)
        C = (alpha*A)*A.' + beta*C
        C = triu(C)
        # move to host and compare
        h_C = to_host(d_C)
        h_C = triu(C)
        @test C ≈ h_C
    end
end

@testset "syrk" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,k)
        # move to device
        d_A = CudaArray(A)
        # C = A*A.'
        d_C = CUBLAS.syrk('U','N',d_A)
        C = A*A.'
        C = triu(C)
        # move to host and compare
        h_C = to_host(d_C)
        h_C = triu(C)
        @test C ≈ h_C
    end
end

@testset "herk!" begin
    @testset for elty in [Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,k)
        C = rand(elty,m,m)
        C = C + C'
        # parameters
        alpha = rand(elty)
        beta = rand(elty)
        # move to device
        d_A = CudaArray(A)
        d_C = CudaArray(C)
        CUBLAS.herk!('U','N',alpha,d_A,beta,d_C)
        C = alpha*(A*A') + beta*C
        C = triu(C)
        # move to host and compare
        h_C = to_host(d_C)
        h_C = triu(C)
        @test C ≈ h_C
    end
end

@testset "herk" begin
    @testset for elty in [Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,k)
        # move to device
        d_A = CudaArray(A)
        # C = A*A'
        d_C = CUBLAS.herk('U','N',d_A)
        C = A*A'
        C = triu(C)
        # move to host and compare
        h_C = to_host(d_C)
        h_C = triu(C)
        @test C ≈ h_C
    end
end

@testset "syr2k!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        #local m = 3
        #local k = 1
        # generate parameters
        alpha = rand(elty)
        beta = rand(elty)
        # generate matrices
        A = rand(elty,m,k)
        B = rand(elty,m,k)
        C = rand(elty,m,m)
        C = C + C.'
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        d_C = CudaArray(C)
        # compute
        #C = alpha*(A*B.') + conj(alpha)*(B*A.') + beta*C
        C = alpha*(A*B.' + B*A.') + beta*C
        CUBLAS.syr2k!('U','N',alpha,d_A,d_B,beta,d_C)
        # move back to host and compare
        C = triu(C)
        h_C = to_host(d_C)
        h_C = triu(h_C)

        @test C ≈ h_C
    end
end

@testset "syr2k" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameters
        alpha = rand(elty)
        # generate matrices
        A = rand(elty,m,k)
        B = rand(elty,m,k)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        # compute
        #C = alpha*(A*B.') + conj(alpha)*(B*A.') + beta*C
        C = alpha*(A*B.' + B*A.')
        d_C = CUBLAS.syr2k('U','N',alpha,d_A,d_B)
        # move back to host and compare
        C = triu(C)
        h_C = to_host(d_C)
        h_C = triu(h_C)
        @test C ≈ h_C
    end
end

@testset "her2k!" begin
    @testset for (elty1, elty2) in [(Complex64, Float32), (Complex128, Float64)]
        # generate parameters
        alpha = rand(elty1)
        beta = rand(elty2)
        # generate matrices
        A = rand(elty1,m,k)
        B = rand(elty1,m,k)
        C = rand(elty1,m,m)
        C = C + C'
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        d_C = CudaArray(C)
        # compute
        #C = alpha*(A*B') + conj(alpha)*(B*A') + beta*C
        C = alpha*(A*B') + conj(alpha)*(B*A') + beta*C
        CUBLAS.her2k!('U','N',alpha,d_A,d_B,beta,d_C)
        # move back to host and compare
        C = triu(C)
        h_C = to_host(d_C)
        h_C = triu(h_C)
        @test C ≈ h_C
    end
end

@testset "her2k" begin
    @testset for elty in [Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,k)
        B = rand(elty,m,k)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        # compute
        C = A*B' + B*A'
        d_C = CUBLAS.her2k('U','N',d_A,d_B)
        # move back to host and compare
        C = triu(C)
        h_C = to_host(d_C)
        h_C = triu(h_C)
        @test C ≈ h_C
    end
end

@testset "trmm!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameter
        alpha = rand(elty)
        # generate matrices
        A = rand(elty,m,m)
        A = triu(A)
        B = rand(elty,m,n)
        C = zeros(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        d_C = CudaArray(C)
        # compute
        C = alpha*A*B
        CUBLAS.trmm!('L','U','N','N',alpha,d_A,d_B,d_C)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

@testset "trmm" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameter
        alpha = rand(elty)
        # generate matrices
        A = rand(elty,m,m)
        A = triu(A)
        B = rand(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        # compute
        C = alpha*A*B
        d_C = CUBLAS.trmm('L','U','N','N',alpha,d_A,d_B)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

@testset "trsm!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameter
        alpha = rand(elty)
        # generate matrices
        A = rand(elty,m,m)
        A = triu(A)
        B = rand(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        # compute
        C = alpha*(A\B)
        CUBLAS.trsm!('L','U','N','N',alpha,d_A,d_B)
        # move to host and compare
        h_C = to_host(d_B)
        @test C ≈ h_C
    end
end

@testset "trsm" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameter
        alpha = rand(elty)
        # generate matrices
        A = rand(elty,m,m)
        A = triu(A)
        B = rand(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        # compute
        C = alpha*(A\B)
        d_C = CUBLAS.trsm('L','U','N','N',alpha,d_A,d_B)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

@testset "trsm_batched!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameter
        alpha = rand(elty)
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        map!((x) -> triu(x), A, A)
        B = [rand(elty,m,n) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        d_B = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
            push!(d_B,CudaArray(B[i]))
        end
        # compute
        CUBLAS.trsm_batched!('L','U','N','N',alpha,d_A,d_B)
        # move to host and compare
        for i in 1:length(d_B)
            C = alpha*(A[i]\B[i])
            h_C = to_host(d_B[i])
            #compare
            @test C ≈ h_C
        end
    end
end

@testset "trsm_batched" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameter
        alpha = rand(elty)
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        map!((x) -> triu(x), A, A)
        B = [rand(elty,m,n) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        d_B = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
            push!(d_B,CudaArray(B[i]))
        end
        # compute
        d_C = CUBLAS.trsm_batched('L','U','N','N',alpha,d_A,d_B)
        # move to host and compare
        for i in 1:length(d_C)
            C = alpha*(A[i]\B[i])
            h_C = to_host(d_C[i])
            @test C ≈ h_C
        end
    end
end

@testset "hemm!" begin
    @testset for elty in [Complex64, Complex128]
        # generate parameters
        alpha = rand(elty)
        beta  = rand(elty)
        # generate matrices
        A = rand(elty,m,m)
        A = A + ctranspose(A)
        @test ishermitian(A)
        B = rand(elty,m,n)
        C = rand(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        d_C = CudaArray(C)
        # compute
        C = alpha*(A*B) + beta*C
        CUBLAS.hemm!('L','L',alpha,d_A,d_B,beta,d_C)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

@testset "hemm" begin
    @testset for elty in [Complex64, Complex128]
        # generate parameter
        alpha = rand(elty)
        # generate matrices
        A = rand(elty,m,m)
        A = A + ctranspose(A)
        @test ishermitian(A)
        B = rand(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        # compute
        C = alpha*(A*B)
        d_C = CUBLAS.hemm('L','U',alpha,d_A,d_B)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

@testset "geam!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameters
        alpha = rand(elty)
        beta  = rand(elty)
        # generate matrices
        A = rand(elty,m,n)
        B = rand(elty,m,n)
        C = zeros(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        d_C = CudaArray(C)
        # compute
        C = alpha*A + beta*B
        CUBLAS.geam!('N','N',alpha,d_A,beta,d_B,d_C)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C

        #test in place versions too
        C = rand(elty,m,n)
        d_C = CudaArray(C)
        C = alpha*C + beta*B
        CUBLAS.geam!('N','N',alpha,d_C,beta,d_B,d_C)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
        C = rand(elty,m,n)
        d_C = CudaArray(C)
        C = alpha*A + beta*C
        CUBLAS.geam!('N','N',alpha,d_A,beta,d_C,d_C)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C

        #test setting C to zero
        C = rand(elty,m,n)
        d_C = CudaArray(C)
        alpha = zero(elty)
        beta  = zero(elty)
        CUBLAS.geam!('N','N',alpha,d_A,beta,d_B,d_C)
        h_C = to_host(d_C)
        @test h_C ≈ zeros(elty,m,n)

        # bounds checking
        @test_throws DimensionMismatch CUBLAS.geam!('N','T',alpha,d_A,beta,d_B,d_C)
        @test_throws DimensionMismatch CUBLAS.geam!('T','T',alpha,d_A,beta,d_B,d_C)
        @test_throws DimensionMismatch CUBLAS.geam!('T','N',alpha,d_A,beta,d_B,d_C)
    end
end

@testset "geam" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate parameter
        alpha = rand(elty)
        beta  = rand(elty)
        # generate matrices
        A = rand(elty,m,n)
        B = rand(elty,m,n)
        # move to device
        d_A = CudaArray(A)
        d_B = CudaArray(B)
        C = zeros(elty,m,n)
        # compute
        C = alpha*A + beta*B
        d_C = CUBLAS.geam('N','N',alpha,d_A,beta,d_B)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

@testset "getrf_batched!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
        end
        pivot, info = CUBLAS.getrf_batched!(d_A, false)
        h_info = to_host(info)
        for As in 1:length(d_A)
            C   = lufact!(copy(A[As]), Val{false}) # lufact(A[As],pivot=false)
            h_A = to_host(d_A[As])
            #reconstruct L,U
            dL = eye(elty,m)
            dU = zeros(elty,(m,m))
            k = h_info[As]
            if( k >= 0 )
                dL += tril(h_A,-k-1)
                dU += triu(h_A,k)
            end
            #compare
            @test isapprox(C[:L], dL, rtol=1e-2)
            @test isapprox(C[:U], dU, rtol=1e-2)
        end
        for i in 1:length(A)
            d_A[ i ] = CudaArray(A[i])
        end
        pivot, info = CUBLAS.getrf_batched!(d_A, true)
        h_info = to_host(info)
        h_pivot = to_host(pivot)
        for As in 1:length(d_A)
            C   = lufact(A[As])
            h_A = to_host(d_A[As])
            #reconstruct L,U
            dL = eye(elty,m)
            dU = zeros(elty,(m,m))
            k = h_info[As]
            if( k >= 0 )
                dL += tril(h_A,-k-1)
                dU += triu(h_A,k)
            end
            #compare pivots
            @test length(setdiff(h_pivot[:,As],C[:p])) == 0
            #make device pivot matrix
            P = eye(m)
            for row in 1:m
                temp = copy(P[row,:])
                P[row,:] = P[h_pivot[row,As],:]
                P[h_pivot[row,As],:] = temp
            end
            @test inv(P)*dL*dU ≈ inv(C[:P]) * C[:L] * C[:U]
        end
    end
end

@testset "getrf_batched" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
        end
        pivot, info, d_B = CUBLAS.getrf_batched(d_A, false)
        h_info = to_host(info)
        for Bs in 1:length(d_B)
            C   = lufact!(copy(A[Bs]),Val{false}) # lufact(A[Bs],pivot=false)
            h_B = to_host(d_B[Bs])
            #reconstruct L,U
            dL = eye(elty,m)
            dU = zeros(elty,(m,m))
            k = h_info[Bs]
            if( h_info[Bs] >= 0 )
                dU += triu(h_B,k)
                dL += tril(h_B,-k-1)
            end
            #compare
            @test isapprox(C[:L], dL, rtol=1e-2)
            @test isapprox(C[:U], dU, rtol=1e-2)
        end
    end
end

@testset "getri_batched" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
        end
        pivot, info = CUBLAS.getrf_batched!(d_A, true)
        h_info = to_host(info)
        for Cs in 1:length(h_info)
            @test h_info[Cs] == 0
        end
        pivot, info, d_C = CUBLAS.getri_batched(d_A, pivot)
        h_info = to_host(info)
        for Cs in 1:length(d_C)
            C   = inv(A[Cs])
            h_C = to_host(d_C[Cs])
            @test h_info[Cs] == 0
            @test C ≈ h_C
        end
    end
end

@testset "matinv_batched" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
        end
        info, d_C = CUBLAS.matinv_batched(d_A)
        for Cs in 1:length(d_C)
            C   = inv(A[Cs])
            h_C = to_host(d_C[Cs])
            @test C ≈ h_C
        end
    end
end

@testset "geqrf_batched!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,m,n) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
        end
        tau, d_A = CUBLAS.geqrf_batched!(d_A)
        for As in 1:length(d_A)
            C   = qrfact(A[As])
            h_A = to_host(d_A[As])
            h_tau = to_host(tau[As])
            # build up Q
            Q = eye(elty,min(m,n))
            for i in 1:min(m,n)
                v = zeros(elty,m)
                v[i] = one(elty)
                v[i+1:m] = h_A[i+1:m,i]
                Q *= eye(elty,m) - h_tau[i] * v * v'
            end
            @test Q≈full(C[:Q])
        end
    end
end

@testset "geqrf_batched" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,m,n) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
        end
        tau, d_B = CUBLAS.geqrf_batched!(d_A)
        for Bs in 1:length(d_B)
            C   = qrfact(A[Bs])
            h_B = to_host(d_B[Bs])
            h_tau = to_host(tau[Bs])
            # build up Q
            Q = eye(elty,min(m,n))
            for i in 1:min(m,n)
                v = zeros(elty,m)
                v[i] = one(elty)
                v[i+1:m] = h_B[i+1:m,i]
                Q *= eye(elty,m) - h_tau[i] * v * v'
            end
            @test Q≈full(C[:Q])
        end
    end
end

@testset "gels_batched!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,n,n) for i in 1:10]
        C = [rand(elty,n,k) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        d_C = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
            push!(d_C,CudaArray(C[i]))
        end
        d_A, d_C, info = CUBLAS.gels_batched!('N',d_A, d_C)
        for Cs in 1:length(d_C)
            X = A[Cs]\C[Cs]
            h_C = to_host(d_C[Cs])
            @test X≈h_C
        end
    end
end

@testset "gels_batched" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = [rand(elty,n,n) for i in 1:10]
        C = [rand(elty,n,k) for i in 1:10]
        # move to device
        d_A = CudaArray{elty, 2}[]
        d_C = CudaArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CudaArray(A[i]))
            push!(d_C,CudaArray(C[i]))
        end
        d_B, d_D, info = CUBLAS.gels_batched('N',d_A, d_C)
        for Ds in 1:length(d_D)
            X = A[Ds]\C[Ds]
            h_D = to_host(d_D[Ds])
            @test X ≈ h_D
        end
    end
end

@testset "dgmm!" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,n)
        C = rand(elty,m,n)
        X = rand(elty,m)
        # move to device
        d_A = CudaArray(A)
        d_C = CudaArray(C)
        d_X = CudaArray(X)
        # compute
        C = diagm(X) * A
        CUBLAS.dgmm!('L',d_A,d_X,d_C)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
        # bounds checking
        @test_throws DimensionMismatch CUBLAS.dgmm!('R',d_A,d_X,d_C)
        A = rand(elty,m,m)
        d_A = CudaArray(A)
        @test_throws DimensionMismatch CUBLAS.dgmm!('L',d_A,d_X,d_C)
    end
end

@testset "dgmm" begin
    @testset for elty in [Float32, Float64, Complex64, Complex128]
        # generate matrices
        A = rand(elty,m,n)
        X = rand(elty,m)
        # move to device
        d_A = CudaArray(A)
        d_X = CudaArray(X)
        # compute
        C = diagm(X) * A
        d_C = CUBLAS.dgmm('L',d_A,d_X)
        # move to host and compare
        h_C = to_host(d_C)
        @test C ≈ h_C
    end
end

