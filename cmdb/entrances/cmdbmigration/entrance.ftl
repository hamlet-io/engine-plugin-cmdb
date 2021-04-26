[#ftl]

[#macro cmdb_entrance_cmdbmigration ]

    [@generateOutput
        deploymentFramework=getCLODeploymentFramework()
        type=getCLODeploymentOutputType()
        format=getCLODeploymentOutputFormat()
    /]

[/#macro]

[#-- Extra command line options --]
[#macro cmdb_entrance_cmdbmigration_inputsteps ]

    [@registerInputSeeder
        id=CMDBMIGRATION_ENTRANCE_TYPE
        description="Entrance options"
    /]

    [@addSeederToConfigPipeline
        stage=COMMANDLINEOPTIONS_SHARED_INPUT_STAGE
        seeder=CMDBMIGRATION_ENTRANCE_TYPE
    /]

[/#macro]

[#function cmdbmigration_configseeder_commandlineoptions filter state ]
    [#return
        addToConfigPipelineClass(
            state,
            COMMAND_LINE_OPTIONS_CONFIG_INPUT_CLASS,
            {
                "Deployment" : {
                    "Framework" : {
                        "Name" : DEFAULT_DEPLOYMENT_FRAMEWORK
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
        )
    ]
[/#function]


