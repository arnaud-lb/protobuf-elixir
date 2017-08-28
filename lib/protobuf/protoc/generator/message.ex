defmodule Protobuf.Protoc.Generator.Message do
  alias Protobuf.Protoc.Generator.Util
  alias Protobuf.TypeUtil
  alias Protobuf.Protoc.Generator.Enum, as: EnumGenerator

  def generate_list(ctx, descs) do
    Enum.map(descs, fn(desc) -> generate(ctx, desc) end)
  end

  def generate(ctx, desc) do
    msg_struct = parse_desc(ctx, desc)
    ctx = %{ctx | namespace: msg_struct[:new_namespace]}
    [gen_msg(msg_struct)] ++ gen_nested_msgs(ctx, desc) ++ gen_nested_enums(ctx, desc)
  end

  def parse_desc(%{namespace: ns, package: pkg} = ctx, desc) do
    new_ns = ns ++ [Util.trans_name(desc.name)]
    fields = get_fields(ctx, desc)
    %{
      new_namespace: new_ns,
      name: new_ns |> Util.join_name |> Util.attach_pkg(pkg),
      options: msg_opts_str(desc.options),
      structs: structs_str(desc),
      typespec: typespec_str(fields),
      fields: fields,
      oneofs: oneofs_str(desc.oneof_decl)
    }
  end

  defp gen_msg(msg_struct) do
    Protobuf.Protoc.Template.message(
      msg_struct[:name],
      msg_struct[:options],
      msg_struct[:structs],
      msg_struct[:typespec],
      msg_struct[:oneofs],
      gen_fields(msg_struct[:fields])
    )
  end

  defp gen_nested_msgs(ctx, desc) do
    Enum.map(desc.nested_type, fn(msg_desc) -> generate(ctx, msg_desc) end)
  end

  defp gen_nested_enums(ctx, desc) do
    Enum.map(desc.enum_type, fn(enum_desc) -> EnumGenerator.generate(ctx, enum_desc) end)
  end

  defp gen_fields(fields) do
    Enum.map(fields, fn(%{opts: opts} = f) ->
      opts_str = Util.options_to_str(opts)
      if opts_str != "" do
        ":#{f[:name]}, #{f[:number]}, #{f[:label]}: true, type: #{f[:type]}, #{opts_str}"
      else
        ":#{f[:name]}, #{f[:number]}, #{f[:label]}: true, type: #{f[:type]}"
      end
    end)
  end

  def msg_opts_str(opts) do
    msg_options = opts
    opts = %{map: msg_options.map_entry, deprecated: msg_options.deprecated}
    str = Util.options_to_str(opts)
    if String.length(str) > 0, do: ", " <> str, else: ""
  end

  def structs_str(struct) do
    Enum.map_join(struct.oneof_decl ++ struct.field, ", ", fn(f) -> ":#{f.name}" end)
  end

  def typespec_str([]), do: ""
  def typespec_str(fields) do
    longest_field = fields |> Enum.max_by(&(String.length(&1[:name])))
    longest_width = String.length(longest_field[:name])

    "  @type t :: %__MODULE__{\n" <>
    Enum.map_join(fields, ",\n", fn(f) ->
      "    #{fmt_type_name(f[:name], longest_width)} #{fmt_type(f)}"
    end) <> "\n  }\n"
  end

  defp oneofs_str(oneofs) do
    oneofs
    |> Enum.with_index
    |> Enum.map(fn({oneof, index}) ->
         "oneof :#{oneof.name}, #{index}"
       end)
  end

  defp fmt_type_name(name, len) do
    String.pad_trailing("#{name}:", len + 1)
  end

  defp fmt_type(%{opts: %{enum: true}, label: "repeated"}), do: "[integer]"
  defp fmt_type(%{opts: %{enum: true}}), do: "integer"
  defp fmt_type(%{opts: %{map: true}, map: {{k_type, k_name}, {v_type, v_name}}}) do
    k_type = type_to_spec(k_type, k_name)
    v_type = type_to_spec(v_type, v_name)
    "%{#{k_type} => #{v_type}}"
  end
  defp fmt_type(%{label: "repeated", type_num: type_num, type: type}) do
    "[#{type_to_spec(type_num, type)}]"
  end
  defp fmt_type(%{type_num: type_num, type: type}) do
    "#{type_to_spec(type_num, type)}"
  end

  defp type_to_spec(11, type), do: TypeUtil.str_to_spec(11, type)
  defp type_to_spec(num, _), do: TypeUtil.str_to_spec(num)

  def get_fields(ctx, desc) do
    oneofs = Enum.map(desc.oneof_decl, &(&1.name))
    nested_maps = nested_maps(ctx, desc)
    Enum.map(desc.field, fn(f) -> get_field(ctx, f, nested_maps, oneofs) end)
  end

  def get_field(ctx, f, nested_maps, oneofs) do
    opts = field_options(f)
    map = nested_maps[f.type_name]
    opts = if map, do: Map.put(opts, :map, true), else: opts
    opts = if length(oneofs) > 0, do: Map.put(opts, :oneof, f.oneof_index), else: opts
    type = TypeUtil.number_to_atom(f.type)
    type = if type == :enum || type == :message do
      Util.trans_type_name(f.type_name, ctx)
    else
      ":#{type}"
    end
    %{name: f.name, number: f.number, label: label_name(f.label), type: type, type_num: f.type, opts: opts, map: map}
  end

  # Map of protobuf are actually nested(one level) messages
  defp nested_maps(ctx, desc) do
    full_name = Util.join_name [ctx.package|ctx.namespace] ++ [desc.name]
    prefix = "." <> full_name
    Enum.reduce(desc.nested_type, %{}, fn(desc, acc) ->
      cond do
        desc.options.map_entry ->
          [k, v] = Enum.sort(desc.field, &(&1.number < &2.number))
          pair = {{k.type, Util.trans_type_name(k.type_name, ctx)},
           {v.type, Util.trans_type_name(v.type_name, ctx)}}
          Map.put(acc, Util.join_name([prefix, desc.name]), pair)
        true -> acc
      end
    end)
  end

  defp field_options(f) do
    opts = %{enum: f.type == 14, default: default_value(f.type, f.default_value)}
    if f.options, do: merge_field_options(opts, f), else: opts
  end

  defp label_name(1), do: "optional"
  defp label_name(2), do: "required"
  defp label_name(3), do: "repeated"

  defp default_value(_, ""), do: nil
  defp default_value(type, value) do
    val = cond do
      type <= 2 ->
        case Float.parse(value) do
          {v, _} -> v
          :error -> value
        end
      type <= 7 || type == 13 || (type >= 15 && type <= 18) ->
        case Integer.parse(value) do
          {v, _} -> v
          :error -> value
        end
      type == 8 -> String.to_atom(value)
      type == 9 || type == 12 -> value
      type == 14 -> String.to_atom(value)
      true -> nil
    end
    if val == nil, do: val, else: inspect(val)
  end

  defp merge_field_options(opts, f) do
    opts
      |> Map.put(:packed, f.options.packed)
      |> Map.put(:deprecated, f.options.deprecated)
  end
end
