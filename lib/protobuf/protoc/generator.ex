defmodule Protobuf.Protoc.Generator do
  alias Protobuf.Protoc.Generator.Message, as: MessageGenerator
  alias Protobuf.Protoc.Generator.Enum, as: EnumGenerator
  alias Protobuf.Protoc.Generator.Service, as: ServiceGenerator

  def generate(ctx, desc) do
    name = new_file_name(desc.name)
    Google_Protobuf_Compiler.CodeGeneratorResponse.File.new(name: name, content: generate_content(ctx, desc))
  end

  defp new_file_name(name) do
    String.replace_suffix(name, ".proto", ".pb.ex")
  end

  def generate_content(ctx, desc) do
    ctx = %{ctx | package: desc.package}
    ctx = %{ctx | dep_pkgs: get_dep_pkgs(ctx, desc.dependency )}
    list =
      MessageGenerator.generate_list(ctx, desc.message_type) ++
      EnumGenerator.generate_list(ctx, desc.enum_type) ++
      ServiceGenerator.generate_list(ctx, desc.service)
    list
    |> List.flatten
    |> Enum.join("\n")
  end

  @doc false
  def get_dep_pkgs(%{pkg_mapping: mapping, package: pkg}, deps) do
    pkgs = deps |> Enum.map(fn(dep) -> mapping[dep] end)
    pkgs = if pkg && String.length(pkg) > 0, do: [pkg | pkgs], else: pkgs
    Enum.sort(pkgs, &(byte_size(&2) <= byte_size(&1)))
  end
end
