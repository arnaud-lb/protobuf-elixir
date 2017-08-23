defmodule Protobuf.MessageProps do
  alias Protobuf.FieldProps
  @type t :: %__MODULE__{
    ordered_tags: [integer],
    tags_map: %{integer => integer},
    field_props: %{integer => FieldProps.T},
    repeated_fields: [atom],
    oneof: [{atom, non_neg_integer}],

    enum?: boolean,
    extendable?: boolean,
    oneof?: boolean,
    map?: boolean,
  }
  defstruct [
    ordered_tags: [],
    tags_map: %{},
    field_props: %{},
    repeated_fields: [],
    oneof: [],

    enum?: false,
    oneof?: false,
    extendable?: false,
    map?: false,
  ]
end
