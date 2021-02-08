[#ftl]

[#macro cmdb_entrance_cmdbinfo ]

  [@addCommandLineOption
      option={
        "Deployment" : {
          "Framework" : {
            "Name" : DEFAULT_DEPLOYMENT_FRAMEWORK
          },
          "Provider" : {
            "Names" : combineEntities(
                        [ "cmdb" ],
                        commandLineOptions.Deployment.Provider.Names,
                        UNIQUE_COMBINE_BEHAVIOUR
                      )
          }
        },
        "View" : {
          "Name" : CMDBINFO_VIEW_TYPE
        },
        "Flow" : {
          "Names" : [ "views" ]
        },
        "CMDB" : {
          "Names" : cmdbs!""
        },
        "Actions" : (actions!"inputs")?split("|"),
        "Filters" : (filters!"")?split("|")
      }
  /]

  [@generateOutput
    deploymentFramework=commandLineOptions.Deployment.Framework.Name
    type=commandLineOptions.Deployment.Output.Type
    format=commandLineOptions.Deployment.Output.Format
  /]

[/#macro]
