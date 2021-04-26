[#ftl]

[#macro cmdb_view_default_cmdbinfo_generationcontract  ]
    [@addDefaultGenerationContract subsets=[ "config" ] /]
[/#macro]

[#macro cmdb_view_default_cmdbinfo_config ]
    [#local options = getCommandLineOptions() ]
    [#local layers = getLayers() ]

    [#-- Locate the layer values we are looking for --]
    [#local tenant = layers[TENANT_LAYER_TYPE].Name ]
    [#local product = layers[PRODUCT_LAYER_TYPE].Name ]
    [#local environment = layers[ENVIRONMENT_LAYER_TYPE].Name ]
    [#local segment = layers[SEGMENT_LAYER_TYPE].Name ]

    [#-- Locate the placement information --]
    [#local account = layers[ACCOUNT_LAYER_TYPE].Name ]
    [#local region = layers[SEGMENT_LAYER_TYPE].Name ]

    [#-- A list of actions to be performed, mainly content to be included in the output --]
    [#local actions = options.Actions ]

    [#-- Output Filters --]
    [#local filters = {} ]
    [#list options.Filters as filter]
        [#local filters += {filter : true} ]
    [/#list]


    [#-- Control if we want the results of cmdb queries to be cached in freemarker --]
    [#local cacheResults = actions?seq_contains("cacheresults") ]

    [#-- Files --]
    [#local tenantFiles = analyseCMDBTenantFiles(tenant, filters, cacheResults) ]
    [#local accountFiles = analyseCMDBAccountFiles(tenant, account, region, filters, cacheResults) ]
    [#local productFiles = analyseCMDBProductFiles(tenant, product, filters, cacheResults) ]
    [#local segmentFiles = analyseCMDBSegmentFiles(tenant, product, environment, segment, account, region, filters, cacheResults) ]

    [#-- Content --]
    [#local tenantContent = getCMDBTenantContent(tenant, cacheResults) ]
    [#local accountContent = getCMDBAccountContent(tenant, account, region, cacheResults) ]
    [#local productContent = getCMDBProductContent(tenant, product, cacheResults) ]
    [#local segmentContent = getCMDBSegmentContent(tenant, product, environment, segment, account, region, cacheResults) ]

    [#-- Permit filtering on the list of cmdbs returned --]
    [#local cmdbs = getCMDBs({"ActiveOnly" : true}) ]
    [#local requiredCMDBs = [] ]
    [#if options.CMDB.Names?has_content]
        [#local requiredCMDBs = options.CMDB.Names?split("|") ]
        [#local cmdbs = cmdbs?filter(entry -> requiredCMDBs?seq_contains(entry.Name)) ]
    [/#if]

    [@addToDefaultJsonOutput
        [#--]
        {
            "InputStateStack" : inputStateStack,
            "InputStateStackHistory" : inputStateStackHistory,
            "InputStateCache" : inputStateCache
        } +
        --]
        attributeIfTrue(
            "Layers",
            actions?seq_contains("layers"),
            {
                "Tenant" : tenant,
                "Account" : account,
                "Product" : product,
                "Environment" : environment,
                "Segment" : segment
            }
        ) +
        attributeIfTrue(
            "Lists",
            actions?seq_contains("lists"),
            {
                "Tenants" : getCMDBTenants(),
                "Accounts" : getCMDBAccounts(tenant),
                "Products" : getCMDBProducts(tenant),
                "Environments" : getCMDBEnvironments(tenant, product),
                "Segments" : getCMDBSegments(tenant, product, environment)
            }
        ) +
        attributeIfTrue(
            "Files",
            actions?seq_contains("files"),
            {
                "Tenant" : tenantFiles,
                "Account" : accountFiles,
                "Product" : productFiles,
                "Segment" : segmentFiles
            }
        ) +
        attributeIfTrue(
            "Content",
            actions?seq_contains("content"),
            {
                "Tenant" : tenantContent,
                "Account" : accountContent,
                "Product" : productContent,
                "Segment" : segmentContent
            }
        ) +
        attributeIfTrue(
            "Cache",
            actions?seq_contains("cache"),
            cmdbCache
        ) +
        attributeIfTrue(
            "CMDBs",
            actions?seq_contains("cmdbs"),
            cmdbs
        ) +
        attributeIfTrue(
            "State",
            actions?seq_contains("state"),
            getInputState()
        )
    /]
[/#macro]
