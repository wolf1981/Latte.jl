#=
Copyright (c) 2015, Intel Corporation

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Intel Corporation nor the names of its contributors
      may be used to endorse or promote products derived from this software
      without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=#

using FactCheck
using Latte

net = Net(8)
data,  data_value   = MemoryDataLayer(net, :data, (227, 227, 3))
label, label_value = MemoryDataLayer(net, :label, (1,))
data_value[:]  = rand(Float32, size(data_value)...) * 256
label_value[:] = map(floor, rand(Float32, size(label_value)...) * 10)
fc1        = InnerProductLayer(:fc1, net, data, 20)
fc2        = InnerProductLayer(:fc2, net, fc1, 10)
loss       = SoftmaxLossLayer(:loss, net, fc2, label)

init(net)


ϵ = 1e-5
input   = get_buffer(net, :fc1value)
weights = get_buffer(net, :fc2weights)
facts("Testing Inner Product Layer") do
    context("Forward") do
        bias    = get_buffer(net, :fc2bias)
        rand!(bias)

        forward(net; phase=Latte.Test)

        expected = weights' * input .+ reshape(bias, prod(size(bias)))
        @fact expected --> roughly(get_buffer(net, :fc2value))
        clear_values(net)

        forward(net; phase=Latte.Test)
        expected = weights' * input .+ reshape(bias, prod(size(bias)))
        @fact expected --> roughly(get_buffer(net, :fc2value))
    end
    context("Backward") do

        ∇input   = get_buffer(net, :fc1∇)
        ∇weights = get_buffer(net, :fc2∇weights)
        fill!(∇weights, 0.0)
        ∇bias    = get_buffer(net, :fc2∇bias)

        backward(net)

        top_diff = get_buffer(net, :fc2∇)
        ∇bias_expected    = sum(top_diff, 2)
        ∇weights_expected = input * top_diff'
        ∇input_expected   = weights * top_diff
        ∇bias_expected = reshape(∇bias_expected, size(∇bias))

        @fact ∇input_expected   --> roughly(∇input)
        # @fact ∇weights_expected --> roughly(sum(∇weights, ndim(∇weights)))
        # @fact ∇bias_expected    --> roughly(sum(∇bias, ndims(∇bias)))
        @fact all(-ϵ .< ∇weights - ∇weights_expected .< ϵ) --> true
        @pending all(-ϵ .< ∇bias - ∇bias_expected .< ϵ) --> true
    end
end

FactCheck.exitstatus()
