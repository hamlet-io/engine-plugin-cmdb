[#ftl]

[#macro cmdb_entrance_cmdbinfo ]

    [@generateOutput
        deploymentFramework=getCLODeploymentFramework()
        type=getCLODeploymentOutputType()
        format=getCLODeploymentOutputFormat()
    /]

[/#macro]

[#-- Extra command line options --]
[#macro cmdb_entrance_cmdbinfo_inputsteps ]

    [@registerInputSeeder
        id=CMDBINFO_ENTRANCE_TYPE
        description="Entrance options"
    /]

    [@addSeederToConfigPipeline
        stage=COMMANDLINEOPTIONS_SHARED_INPUT_STAGE
        seeder=CMDBINFO_ENTRANCE_TYPE
    /]

[/#macro]

[#function cmdbinfo_configseeder_commandlineoptions filter state ]
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
                    "Name" : CMDBINFO_VIEW_TYPE
                },
                "Flow" : {
                    "Names" : [ "views" ]
                },
                "CMDB" : {
                    "Names" : cmdbs!""
                },
                "Actions" : (actions!"layers")?split("|"),
                "Filters" : (filters!"")?split("|")
            }
        )
    ]
[/#function]