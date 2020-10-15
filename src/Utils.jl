############################################################################ hyperparameter updates
function getParameters(data::StateSpace{N,T}; maxIter::Int=800, tol=1e-6, kwargs...) where {N,T<:Number}
	newtonOptions = NewtonPar(verbose=false,maxIter=maxIter,tol=T(tol))

	# support for StaticArrays github.com/JuliaArrays/StaticArrays.jl/issues/73
	newtonOptions = @set newtonOptions.linsolver.useFactorization = false
	return ContinuationPar(

        pMin=minimum(data.parameter), pMax=maximum(data.parameter), maxSteps=10*length(data.parameter),
        ds=step(data.parameter), dsmax=step(data.parameter), dsmin=step(data.parameter),

		newtonOptions=newtonOptions, detectFold=false, detectBifurcation=true,
		saveEigenvectors=false, nev=N )
end

function updateParameters!(parameters::ContinuationPar{T, S, E}, steady_states::Vector{Branch{V,T}};
    resolution=400 ) where {T<:Number, V<:AbstractVector{T}, S<:AbstractLinearSolver, E<:AbstractEigenSolver}

    # estimate scale from steady state curves
    branch_points = map(length,steady_states)
    ds = maximum(branch_points)*parameters.ds/resolution
    parameters = setproperties(parameters;ds=ds,dsmin=ds,dsmax=ds)
end

############################################################################# training loop
function train!( F::Function, parameters::NamedTuple, data::StateSpace;
				 iter::Int=200, optimiser=Momentum(0.001), plot_solution = false, kwargs...)

	hyperparameters = getParameters(data;kwargs...)
	Loss = steady_states = nothing

	∇Loss = similar(parameters.θ)
	trajectory = typeof(parameters.θ)[]

	for i=1:iter
		try
			steady_states = deflationContinuation(F,data.roots,parameters,hyperparameters;kwargs...)
			Loss,∇Loss = ∇loss(Ref(F),steady_states,Ref(parameters.θ),data.targets;kwargs...)

		catch error
			printstyled(color=:red,   "Iteration $i\tError = $error\n") end
			printstyled(color=:yellow,"Iteration $i\tLoss = $Loss\n")

		printstyled(color=:blue,"$steady_states\n")
		println("Parameters\t$(parameters.θ)")
		println("Gradients\t$(∇Loss)")
		if isinf(Loss) throw("infinite loss") end

		update!(optimiser, parameters.θ, ∇Loss )
		push!(trajectory,copy(parameters.θ))
		if plot_solution>0 if i%plot_solution==0 plot(steady_states,data) end end
	end

	return trajectory
end

############################################################################## loss evaluation helper
function loss(F::Function, θ::AbstractVector, data::StateSpace, hyperparameters::ContinuationPar; plot_densities = false, kwargs...)

	try
		parameters = (θ=θ,p=minimum(data.parameter))
		steady_states = deflationContinuation(F,data.roots,parameters,hyperparameters;kwargs...)

		if plot_densities

			plot(size=(400,400))
			Δi = 0.25
			for (i,branch) ∈ enumerate(steady_states)

				densityA = bifucation_weight.(Ref(F),branch.solutions,Ref(θ);kwargs...) / sum( bifucation_norm.(Ref(F),steady_states,Ref(θ);kwargs...) )
				densityB = target_weight.(data.targets,branch.solutions;kwargs...) / sum( target_norm.(data.targets,steady_states;kwargs...) )
				arclength = cumsum(branch.ds) .- sum(cumsum(branch.ds)) / length(branch)

				plot!( arclength, Δi*i.+min.(densityA,densityB), label="", linewidth=0, fillrange=Δi*i, fillcolor=:gold, alpha=0.5 )
				plot!( arclength, Δi*i.+densityB, label="", color=:gold )
				plot!( arclength, Δi*i.+densityA, label="", color=:red )

			end

			plot!([NaN],[NaN],color=:red, label="Bifurcations")
			plot!([NaN],[NaN],color=:gold,label="Targets")
			plot!(xlabel=L"\mathrm{Arclength}\quad s",ylabel=L"\mathrm{Density}\quad p(s)") |> display
		end

		return loss(Ref(F),steady_states,Ref(θ),data.targets;kwargs...)

	catch error
		printstyled(color=:red,"$error\n")
		return NaN
	end
end

function loss(F::Function, θ::AbstractVector, data::StateSpace; kwargs...)
	return loss(F,θ,data,getParameters(data); kwargs...)
end

############################################################################# plotting
import Plots: plot
function plot(steady_states::Vector{<:Branch}; displayPlot=true)

	plot(xlabel=L"\mathrm{parameter,}p", grid=false, right_margin=20mm, size=(500,400) )
	right_axis = twinx()

    for branch ∈ steady_states

        stability = map( λ -> all(real(λ).<0), branch.eigvals)
        determinants = map( λ -> prod(real(λ)), branch.eigvals)
		parameter = map(z->z.p,branch.solutions)

		for idx ∈ 1:dim(branch)

			plot!( parameter, map(z->z.u[idx],branch.solutions), linewidth=2, label="",
				ylabel=L"\mathrm{steady\,states}\quad F_{\theta}(u,p)=0", alpha=0.5,
				color=map( stable -> stable ? :darkblue : :lightblue, stability )
			)
		end

		plot!(right_axis, parameter, determinants, linewidth=2, label="",
        	ylabel=L"\mathrm{determinant}\,\,\Delta_{\theta}(u,p)",
            color=map( stable -> stable ? :red : :pink, stability )
		)
    end

	if displayPlot plot!() |> display
	else return right_axis end
end

function plot(steady_states::Vector{<:Branch}, data::StateSpace)
	right_axis = plot(steady_states; displayPlot=false)
	vline!( data.targets.x, label="", color=:gold)
	plot!( right_axis,[],[], color=:gold, legend=:bottomleft, alpha=1.0, label="") |> display
end

function plot(F::Function, θ::AbstractVector, data::StateSpace; kwargs...)

	parameters = (θ=θ,p=minimum(data.parameter))
	hyperparameters = getParameters(data;kwargs...)

	steady_states = deflationContinuation(F,data.roots,parameters,hyperparameters;kwargs...)
	println(steady_states)
	plot(steady_states,data)
end
