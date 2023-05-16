defmodule ArkeServer.Schemas do
  alias OpenApiSpex.Schema

  defmodule UnitStruct do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Unit Struct",
      description: "Struct of a unit",
      type: :object,
      properties: %{
        label: %Schema{type: :string, example: "Test", description: "Label of the unit"},
        parameters: %Schema{
          type: :array,
          description: "Parameters of the Unit",
          items: [
            oneOf: [
              %OpenApiSpex.Reference{"$ref": "#/components/schemas/IntegerParameterUnit"},
              %OpenApiSpex.Reference{"$ref": "#/components/schemas/StringParameterUnit"}
            ]
          ]
        }
      }
    })
  end

  defmodule StringParameter do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "StringParameterUnit",
      type: :object,
      properties: %{
        default: %Schema{
          type: :string,
          example: "Default value",
          nullable: true,
          description: "Default value of the parameter"
        },
        helper_text: %Schema{type: :string, nullable: true},
        id: %Schema{
          type: :string,
          example: "first_name",
          nullable: false,
          description: "ID of the unit representing the parameter"
        },
        label: %Schema{
          type: :string,
          example: "I am a label",
          nullable: false,
          description: "Label of the unit"
        },
        max_length: %Schema{type: :integer, example: 100, description: "Max length of the string"},
        min_length: %Schema{type: :integer, example: 3, description: "Min length of the string"},
        type: %Schema{type: :string, example: "string", description: "Type of the parameter"}
      }
    })
  end

  defmodule IntegerParameter do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "IntegerParameterUnit",
      type: :object,
      properties: %{
        default: %Schema{
          type: :integer,
          example: 7,
          nullable: true,
          description: "Default value of the parameter"
        },
        helper_text: %Schema{type: :string, nullable: true},
        id: %Schema{
          type: :string,
          example: "age",
          nullable: false,
          description: "ID of the unit representing the parameter"
        },
        label: %Schema{
          type: :string,
          example: "I am a label",
          nullable: false,
          description: "Label of the unit"
        },
        max: %Schema{type: :integer, example: 100, description: "Max value"},
        min: %Schema{type: :integer, example: 3, description: "Min value"},
        type: %Schema{type: :string, example: "integer", description: "Type of the parameter"}
      }
    })
  end

  defmodule StringParameterUnit do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "String unit parameter",
      description: "String unit parameter",
      type: :object,
      allOf: [
        StringParameter,
        %Schema{
          type: :object,
          properties: %{
            value: %Schema{
              example: "Test value",
              type: :string
            }
          }
        }
      ]
    })
  end

  defmodule IntegerParameterUnit do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Integer unit parameter",
      description: "Integer unit parameter",
      type: :object,
      allOf: [
        IntegerParameter,
        %Schema{
          type: :object,
          properties: %{
            value: %Schema{
              example: 10,
              type: :integer
            }
          }
        }
      ]
    })
  end

  defmodule UnitParameter do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Parameter example",
      description: "Some parameter for the Units",
      type: :object,
      properties: %{
        parameter_1: %Schema{
          type: :string,
          example: "first_name",
          nullable: true,
          description: "One of the unit parameters"
        },
        parameter_2: %Schema{
          type: :string,
          example: "last_name",
          nullable: false,
          description: "Another unit parameter"
        },
        parameter_n: %Schema{
          type: :string,
          example: "[...]",
          nullable: false,
          description: "Another unit parameter"
        }
      }
    })
  end

  defmodule CreateUnitExample do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Create unit example",
      description: "Create unit example",
      type: :object,
      allOf: [
        UnitParameter
      ]
    })
  end

  defmodule UnitExample do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Unit example",
      description: "Unit example",
      type: :object,
      allOf: [
        %Schema{
          type: :object,
          properties: %{
            arke_id: %Schema{
              type: :string,
              example: "id_arke_example",
              description: "Arke ID"
            },
            id: %Schema{
              type: :string,
              example: "123e4567-e89b-12d3-a456-426614174000",
              nullable: false,
              description: "ID of the unit"
            }
          }
        },
        UnitParameter,
        %Schema{
          type: :object,
          properties: %{
            inserted_at: %Schema{
              type: :string,
              format: "date-time",
              description: "When it has been created"
            },
            updated_at: %Schema{
              type: :string,
              format: "date-time",
              description: "Last time it has been updated"
            }
          }
        }
      ]
    })
  end

  defmodule GroupExample do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Group example",
      description: "Group example",
      type: :object,
      properties: %{
        arke_id: %Schema{
          type: :string,
          example: "id_group",
          description: "Group ID"
        },
        arke_list: %Schema{
          type: :array,
          items: %{},
          example: "[]",
          description: "List of Arke linked to the group"
        },
        id: %Schema{
          type: :string,
          example: "group_1",
          description: "UUID or value assigned during creation"
        },
        label: %Schema{
          type: :string,
          example: "I am the group label",
          description: "Group label"
        },
        description: %Schema{
          type: :string,
          example:
            "Consectetur aliquip sunt tempor incididunt Lorem sint ex mollit reprehenderit et anim",
          nullable: false,
          description: "Group Description"
        },
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When it has been created"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Last time it has been updated"
        }
      }
    })
  end

  defmodule UserExample do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "User example",
      description: "User example",
      type: :object,
      properties: %{
        address: %Schema{
          type: :string,
          nullable: true,
          example: nil,
          description: "Address"
        },
        first_name: %Schema{
          type: :string,
          example: "John",
          nullable: true,
          description: "First name of the user"
        },
        last_name: %Schema{
          type: :string,
          example: "Doe",
          nullable: true,
          description: "Last name of the user"
        },
        username: %Schema{
          type: :string,
          nullable: false,
          example: "jdoe",
          description: "Username of the user"
        },
        phone_number: %Schema{
          type: :string,
          example: "2124567890",
          nullable: true,
          description: "Phone Number"
        },
        type: %Schema{
          type: :string,
          example: "true",
          nullable: false,
          description: "Type of the user [customer, admin, super_admin]"
        },
        fiscal_code: %Schema{
          type: :string,
          example: nil,
          nullable: true,
          description: "Fiscal code"
        }
      }
    })
  end

  defmodule UserParams do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Signin Parameter",
      description: "POST body for creating a user",
      type: :object,
      properties: %{
        username: %Schema{
          type: :string,
          nullable: false,
          description: "Username"
        },
        password: %Schema{
          type: :string,
          nullable: false,
          description: "Password",
          format: "password"
        }
      },
      required: [:username, :password],
      example: %{
        "username" => "jdoe",
        "password" => "jdoe_password"
      }
    })
  end
end
