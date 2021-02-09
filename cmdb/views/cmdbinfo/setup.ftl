[#ftl]

[#macro cmdb_view_default_cmdbinfo_generationcontract  ]
    [@addDefaultGenerationContract subsets=[ "config" ] /]
[/#macro]

[#macro cmdb_view_default_cmdbinfo_config ]
    [#-- Have the wrapper assess the CMDBs it finds configured --]
    [@initialiseCMDB /]

    [#-- Now analyse the structure of the CMDBS --]
    [@analyseCMDBStructure /]

    [#-- Locate the layer values we are looking for --]
    [#local tenant = commandLineOptions.Layers.Tenant?split("|")[0]]
    [#local account = commandLineOptions.Layers.Account?split("|")[0]]
    [#local product = commandLineOptions.Layers.Product?split("|")[0]]
    [#local environment = commandLineOptions.Layers.Environment?split("|")[0]]
    [#local segment = commandLineOptions.Layers.Segment?split("|")[0]]

    [#-- Default the tenant if only one --]
    [#local tenants = getCMDBTenants() ]
    [#if !tenant?has_content && tenants?size == 1]
        [#local tenant = tenants[0] ]
    [/#if]

    [#-- Create the contextfilter --]
    [#local contextFilter =
        {
            "Tenant" : combineEntities(commandLineOptions.Layers.Tenant?split("|"), arrayIfContent(tenant, tenant), UNIQUE_COMBINE_BEHAVIOUR),
            "Account" : commandLineOptions.Layers.Account?split("|"),
            "Product" : commandLineOptions.Layers.Product?split("|"),
            "Environment" : commandLineOptions.Layers.Environment?split("|"),
            "Segment" : commandLineOptions.Layers.Segment?split("|")
        }
    ]

    [#-- A list of actions to be performed, mainly content to be included in the output --]
    [#local actions = commandLineOptions.Actions ]

    [#-- Filters --]
    [#local filters = {} ]
    [#list commandLineOptions.Actions as filter]
        [#local filters += {action : filter} ]
    [/#list]


    [#-- Control if we want the results of cmdb queries to be cached in freemarker --]
    [#local cacheResults = actions?seq_contains("cacheresults") ]

    [#-- Files --]
    [#local tenantFiles = analyseCMDBTenantFiles(tenant, filters, cacheResults) ]
    [#local accountFiles = analyseCMDBAccountFiles(tenant, account, filters, cacheResults) ]
    [#local productFiles = analyseCMDBProductFiles(tenant, product, filters, cacheResults) ]
    [#local segmentFiles = analyseCMDBSegmentFiles(tenant, product, environment, segment, filters, cacheResults) ]

    [#-- Content --]
    [#local tenantContent = getCMDBTenantContent(tenant, cacheResults) ]
    [#local accountContent = getCMDBAccountContent(tenant, account, cacheResults) ]
    [#local productContent = getCMDBProductContent(tenant, product, cacheResults) ]
    [#local segmentContent = getCMDBSegmentContent(tenant, product, environment, segment, cacheResults) ]

    [#-- Content qualified with the contextFilter --]

    [#local qualifiedTenantContent = qualifyEntity(tenantContent, contextFilter) ]
    [#local qualifiedAccountContent = qualifyEntity(accountContent, contextFilter) ]
    [#local qualifiedProductContent = qualifyEntity(productContent, contextFilter) ]
    [#local qualifiedSegmentContent = qualifyEntity(segmentContent, contextFilter) ]

    [#-- Permit filtering on the list of cmdbs returned --]
    [#local cmdbs = getCMDBs({"ActiveOnly" : true}) ]
    [#local requiredCMDBs = [] ]
    [#if commandLineOptions.CMDB.Names?has_content]
        [#local requiredCMDBs = commandLineOptions.CMDB.Names?split("|") ]
        [#local cmdbs = cmdbs?filter(entry -> requiredCMDBs?seq_contains(entry.Name)) ]
    [/#if]

    [@addToDefaultJsonOutput
        attributeIfTrue(
            "Inputs",
            actions?seq_contains("inputs"),
            {
                "Tenant" : tenant,
                "Account" : account,
                "Product" : product,
                "Environment" : environment,
                "Segment" : segment
            } +
            attributeIfContent(
                "Cmdbs",
                requiredCMDBs
            )
        ) +
        attributeIfTrue(
            "ContextFilter",
            actions?seq_contains("context"),
            contextFilter
        ) +
        attributeIfTrue(
            "Lists",
            actions?seq_contains("lists"),
            {
                "Tenants" : tenants,
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
            "QualifiedContent",
            actions?seq_contains("qualified"),
            {
                "Tenant" : qualifiedTenantContent,
                "Account" : qualifiedAccountContent,
                "Product" : qualifiedProductContent,
                "Segment" : qualifiedSegmentContent
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
        )
    /]
[/#macro]
