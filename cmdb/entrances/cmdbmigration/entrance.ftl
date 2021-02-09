[#ftl]

[#macro cmdb_entrance_cmdbmigration ]

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
          "Name" : CMDBMIGRATION_VIEW_TYPE
        },
        "Flow" : {
          "Names" : [ "views" ]
        },
        "CMDB" : {
          "Names" : cmdbs!"",
          "Version" : {
            "Upgrade" : upgrade!"v2.0.1",
            "Cleanup" : cleanup!"v2.0.0"
          },
          "Actions" : (actions!"upgrade|cleanup")?lower_case,
          "Dryrun" : valueIfContent(" (dryrun)", dryrun!"", "")
        }
      }
  /]

  [@generateOutput
    deploymentFramework=commandLineOptions.Deployment.Framework.Name
    type=commandLineOptions.Deployment.Output.Type
    format=commandLineOptions.Deployment.Output.Format
  /]

[/#macro]
