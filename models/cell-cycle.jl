function rates( u,p, θ₁=0.0, θ₂=0.0, θ₃=0.0, θ₄=0.0, θ₅=0.0, θ₆=0.0, θ₇=0.0, θ₈=0.0)
	return [ θ₁*p - ( θ₂ + θ₃*u[2] )*u[1],
			 θ₄*(1-u[2])/(0.01+1-u[2]) - (θ₆+θ₇*u[1])*u[2]/(0.01+u[2]) ]
end

function jacobian( u,p, θ₁=0.0, θ₂=0.0, θ₃=0.0, θ₄=0.0, θ₅=0.0, θ₆=0.0, θ₇=0.0, θ₈=0.0)
	return [[ θ₂ + θ₃*u[2] , θ₃*u[1] ] [ -θ₇*u[2]/(u[2]+0.01), -0.01*θ₄/(0.01+1-u[2])^2 - 0.01*(θ₆+θ₇*u[1])/(0.01+u[2])^2 ]]
end