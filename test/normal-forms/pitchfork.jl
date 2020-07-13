######################################################## model
function rates(u::Vector{T},parameters::NamedTuple{(:θ,:p),Tuple{Vector{U},U}}) where {T<:Number,U<:Number}
	@unpack θ,p = parameters; r,α = θ
	θ₁,θ₂ = r*cos(α), r*sin(α)
	return [ θ₁ + p * u[1] + θ₂ * u[1]^3, u[1]-u[2] ]
end

function rates(u::CuArray{T},p::CuArray{T},parameters::NamedTuple{(:θ,:p),Tuple{Vector{U},U}}) where {T<:Number,U<:Number}
	@unpack θ = parameters; r,α = θ
	θ₁,θ₂ = r*cos(α), r*sin(α)
	return θ₁ .+ p .* u[1,:] .+ θ₂ .* u[1,:].^3, u[1,:].-u[2,:]
end

function determinant(u::CuArray{T},p::CuArray{T},parameters::NamedTuple{(:θ,:p),Tuple{Vector{U},U}}) where {T<:Number,U<:Number}
	@unpack θ = parameters; r,α = θ
	θ₁,θ₂ = r*cos(α), r*sin(α)
	return -p .- 3θ₂.*u[1,:].^2
end

function curvature(u::CuArray{T},p::CuArray{T},parameters::NamedTuple{(:θ,:p),Tuple{Vector{U},U}}) where {T<:Number,U<:Number}
	@unpack θ = parameters; r,α = θ
	θ₁,θ₂ = r*cos(α), r*sin(α)
	return -2 .* u[1,:].^2 .* ( p .+ 3θ₂.*u[1,:].^2 ) .* ( 9θ₂.*(p .+ θ₂.*u[1,:].^2) .+ 2) ./ ( p .^2 .+ 6θ₂.*p .* u[1,:].^2 .+ 9θ₂^2 .*u[1,:].^4 .+ 2 .*u[1,:].^2 ).^2
end

function likelihood(u::CuArray{T},p::CuArray{T},parameters::NamedTuple{(:θ,:p),Tuple{Vector{U},U}}; ϵ = 0.1 ) where {T<:Number,U<:Number}
	predictions = exp.( -determinant(u,p,parameters).^2 )
	targets     = exp.( -(targetData.bifurcations'.-p).^2 ./ ϵ )
	return targets .* predictions
end

######################################################### initialise targets, model and hyperparameters
targetData = StateDensity(-5:0.01:5,cu([0.0]))
hyperparameters = getParameters(targetData)

u₀ = [[0.0 0.0], [0.0 0.0]]
parameters = ( θ=[4.0,6π/4+0.1], p=minimum(targetData.parameter) )
