defmodule TestMsg do
  defmodule Foo.Bar do
    use Protobuf

    defstruct [:a, :b]

    field :a, 1, optional: true, type: :int32
    field :b, 2, optional: true, type: :string
  end

  defmodule EnumFoo do
    use Protobuf, enum: true

    field :A, 1
    field :B, 2
    field :C, 4
  end

  defmodule MapFoo do
    use Protobuf, map: true

    defstruct [:key, :value]
    field :key, 1, optional: true, type: :string
    field :value, 2, optional: true, type: :int32
  end

  defmodule Foo do
    use Protobuf

    defstruct [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j, :k, :l, :m]

    field :a, 1, required: true, type: :int32
    field :b, 2, optional: true, type: :fixed64, default: 5
    field :c, 3, optional: true, type: :string
    # 4 is skipped for testing
    field :d, 5, optional: true, type: :float
    field :e, 6, optional: true, type: Foo.Bar
    field :f, 7, optional: true, type: :int32
    field :g, 8, repeated: true, type: :int32
    field :h, 9, repeated: true, type: Foo.Bar
    field :i, 10, repeated: true, type: :int32, packed: true
    field :j, 11, optional: true, type: EnumFoo, enum: true
    field :k, 12, optioanl: true, type: :bool
    field :l, 13, repeated: true, type: MapFoo, map: true
    field :m, 14, optional: true, type: EnumFoo, default: :B, enum: true
  end

  defmodule Oneof do
    use Protobuf

    defstruct [:one, :a, :b, :two, :c, :d]

    oneof :first, 0
    oneof :second, 1
    field :a, 1, optional: true, type: :int32, oneof: 0
    field :b, 2, optional: true, type: :string, oneof: 0
    field :c, 3, optional: true, type: :int32, oneof: 1
    field :d, 4, optional: true, type: :string, oneof: 1
  end
end
