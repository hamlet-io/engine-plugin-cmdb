[#ftl]

[@registerInputSeeder
    id=CMDB_INPUT_SEEDER
    description="Dynamic CMDB lookup"
/]

[@addSeederToConfigPipeline
    stage=CMDB_SHARED_INPUT_STAGE
    seeder=CMDB_INPUT_SEEDER
/]

[#-- Dynamic CMDB lookup --]
[#function cmdb_configseeder_cmdb filter state]

    [#-- Extract key layer info from the filter --]
    [#local tenant = getFilterAttributePrimaryValue(filter, "Tenant") ]
    [#local product = getFilterAttributePrimaryValue(filter, "Product") ]
    [#local environment = getFilterAttributePrimaryValue(filter, "Environment") ]
    [#local segment = getFilterAttributePrimaryValue(filter, "Segment") ]

    [#local account = getFilterAttributePrimaryValue(filter, "Account") ]
    [#local region = getFilterAttributePrimaryValue(filter, "Region") ]

    [#-- Apply defaults --]
    [#-- If no tenant provided and only one available, use it --]
    [#if (! tenant?has_content) && (getCMDBTenants()?size == 1) ]
        [#local tenant = getCMDBTenants()[0] ]
    [/#if]

    [#-- Determine the available content --]
    [#local tenantContent = getCMDBTenantContent(tenant) ]
    [#local accountContent = getCMDBAccountContent(tenant, account, region) ]
    [#local productContent = getCMDBProductContent(tenant, product) ]
    [#local segmentContent = getCMDBSegmentContent(tenant, product, environment, segment, account, region) ]

    [#-- Assemble content by class --]
    [#local blueprintContent =
        mergeObjects(
            tenantContent.Blueprint,
            accountContent.Blueprint,
            productContent.Blueprint,
            segmentContent.Blueprint
        )
    ]
    [#local settingsContent =
        mergeObjects(
            internalReformatAccountSettings(account, accountContent.Settings),
            internalReformatProductSettings(product, segmentContent.Settings)
        )
    ]
    [#local definitionsContent = segmentContent.Definitions ]
    [#local fragmentsContent = segmentContent.Fragments ]

    [#local stateContent =
        accountContent.Stacks +
        segmentContent.Stacks
    ]

    [#local modulesContent =
            tenantContent.Modules +
            accountContent.Modules +
            productContent.Modules
    ]

    [#local extensionsContent =
            tenantContent.Extensions +
            accountContent.Extensions +
            productContent.Extensions
    ]

    [#-- Combine content with the provided state --]
    [#local result = state ]

    [#-- Blueprint needed for plugin/module determination --]
    [#local result =
        addToConfigPipelineClass(
            result,
            BLUEPRINT_CONFIG_INPUT_CLASS,
            blueprintContent,
            CMDB_SHARED_INPUT_STAGE
        )
    ]

    [#-- Cache settings ready for normalisation --]
    [#local result =
        addToConfigPipelineStageCacheForClass(
            result,
            SETTINGS_CONFIG_INPUT_CLASS,
            settingsContent,
            CMDB_SHARED_INPUT_STAGE
        )
    ]

    [#-- Cache definitions ready for normalisation --]
    [#local result =
        addToConfigPipelineStageCacheForClass(
            result,
            DEFINITIONS_CONFIG_INPUT_CLASS,
            definitionsContent,
            CMDB_SHARED_INPUT_STAGE
        )
    ]

    [#-- If content, replace any fragments provided by earlier seeders --]
    [#-- Content is an array so merge will replace any existing content --]
    [#-- Fragments are not affected by plugin/module determination --]
    [#if fragmentsContent?has_content]
        [#local result =
            addToConfigPipelineClass(
                result,
                FRAGMENTS_CONFIG_INPUT_CLASS,
                fragmentsContent,
                "",
                MERGE_COMBINE_BEHAVIOUR
            )
        ]
    [/#if]

    [#-- Cache stack outputs ready for normalisation --]
    [#-- If content, replace any state provided by earlier seeders --]
    [#-- Content is an array so merge will replace any existing content --]
    [#if stateContent?has_content]
        [#local result =
            addToConfigPipelineStageCacheForClass(
                result,
                STATE_CONFIG_INPUT_CLASS,
                stateContent,
                CMDB_SHARED_INPUT_STAGE,
                MERGE_COMBINE_BEHAVIOUR
            )
        ]
    [/#if]

    [#-- Ensure modules are loaded --]
    [#-- TODO(mfl) Add logic to only load once - current module logic is idempotent --]
    [#list modulesContent as module]
        [#include module.File]
    [/#list]

    [#-- Ensure extensions are loaded --]
    [#-- TODO(mfl) Add logic to only load once - current extension logic is idempotent --]
    [#list extensionsContent as extension]
        [#include extension.File]
    [/#list]

    [#return result]

[/#function]

[#----------------------------------------------
-- Internal support functions for cmdb seeder --
------------------------------------------------]
[#-- TODO(mfl) Remove these once composite inputs decommissioned --]
[#function internalReformatAccountSettings key cmdbSettings]
    [#local settings = {} ]
    [#list cmdbSettings.General as namespace,value]
        [#local settings +=
            {
                formatName(key,namespace) : value
            }
        ]
    [/#list]
    [#return
        {
            "Settings" : {
                "Accounts" : settings
            }
        }
    ]
[/#function]

[#function internalReformatProductSettings key cmdbSettings]
    [#local settings = {} ]
    [#list cmdbSettings.General as namespace,value]
        [#local settings +=
            {
                formatName(key,namespace) : value
            }
        ]
    [/#list]
    [#local builds = {} ]
    [#list cmdbSettings.Builds as namespace,value]
        [#local builds +=
            {
                formatName(key,namespace) : value
            }
        ]
    [/#list]
    [#local sensitive = {} ]
    [#list cmdbSettings.Sensitive as namespace,value]
        [#local sensitive +=
            {
                formatName(key,namespace) : value
            }
        ]
    [/#list]
    [#return
        {
            "Settings" : {
                "Products" : settings
            },
            "Builds" : {
                "Products" : builds
            },
            "Sensitive" : {
                "Products" : sensitive
            }
        }
    ]
[/#function]

