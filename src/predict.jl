function likelihood(vm::VectorModel, doc::DenseArray{Tw},
		window_length::Int)

	N = length(doc)

	z = zeros(T(vm))

	ll = 0.
	n = 0
	for i in 1:N
		x = doc[i]

		window = window_length
		z[:] = 0.

		expected_pi!(z, vm, x)

		for j in max(1, i - window):min(N, i + window)
			if i == j continue end
			y = doc[j]

			local_ll = 0.
			for s in 1:T(vm)
				if z[s] < 1e-5 continue end
				In = view(vm, x, s)

				local_ll += z[s] * exp(log_skip_gram(vm, x, s, y))
			end
			ll += log(local_ll)

			n += 1
		end
	end
	return ll, n
end

function skip_gram{Tw <: Integer}(vm::VectorModel, x::Tw, context::AbstractArray{Tw},
		z::DenseArray{Float64}=zeros(T(vm)))
	ll = 0.
	expected_pi!(z, vm, x)
	for y in context
		for s in 1:T(vm)
			if z[s] < 1e-5 continue end
			In = view(vm, x, s)

			output = vm.outputs[y]
			ll += z[s] * exp(ccall((:skip_gram, "superlib"), Float32,
			(Ptr{Float32}, Ptr{Float32},
				Int,
				Ptr{Int}, Ptr{Int8}, Int),
			In, sdata(vm.Out),
				M(vm),
				output.path, output.code, length(output)))
		end
	end

	return ll / length(context)
end

function likelihood(vm::VectorModel, dict::Dictionary, f::IO,
		window_length::Int; batch::Int=16777216)
	buffer = zeros(Int32, batch)
	j = 0
	ll = 0.
	while !eof(f)
		doc = read_words(f, dict, buffer, length(buffer), -1)
		if length(doc) == 0 break end
		#println(j)
		local_ll, n = likelihood(vm, doc, window_length)
		ll += local_ll
		j += n
	end
	return ll / j
end

function text_likelihood(vm::VectorModel, dict::Dictionary, s::String,
		window_length::Int, batch::Int=16777216)
	buffer = zeros(Int32, batch)
	doc = read_words(s, dict, buffer, length(buffer), -1)
	ll, j = likelihood(vm, doc, window_length)
	return ll / j
end

export text_likelihood, skip_gram


function likelihood(vm::VectorModel, dict::Dictionary, path::String,
		window_length::Int; batch::Int=16777216)
	f = open(path)
	ll = likelihood(vm, dict, f, window_length; batch = batch)
	close(f)
	return ll
end