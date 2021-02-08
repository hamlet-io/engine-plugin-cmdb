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
            "Upgrade" : upgrade!"v1.3.2",
            "Cleanup" : cleanup!"v1.1.1"
          },
          "Actions" : (actions!"upgrade")?lower_case,
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
