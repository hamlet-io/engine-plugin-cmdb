[#ftl]
[#assign start = .now]
[#assign timer = start]

[#include "base.ftl" ]
[#--include "./cmdb/cmdb.ftl"--]

[#assign elapsedLog = [] ]

[#function elapsedTime timer event context={}]
    [#local currentTime = .now]
    [#assign elapsedLog +=
        [
            {
                "Event" : event,
                "Elapsed" : (duration(currentTime, timer)/1000)?string["0.000"] + "s"
            } +
            attributeIfContent("Context", context)
        ]
    ]
    [#return currentTime]
[/#function]

[#assign timer = elapsedTime(timer, "Load") ]

[#--@analyseCMDBStructure /]
[#assign timer = elapsedTime(timer, "Analyse CMDB") --]

[
[#--@toJSON getCMDBTenants() /],
[@toJSON getCMDBAccounts("dibp") /],
[@toJSON getCMDBProducts("dibp") /],
[@toJSON getCMDBEnvironments("dibp", "ics") /],
[@toJSON getCMDBSegments("dibp", "ics", "e4") /],
[@toJSON analyseCMDBTenantFiles("dibp", {"FlattenedFilenamesOnly" : true}) /],
[@toJSON analyseCMDBAccountFiles("dibp", "dibpnp22", {"FlattenedFilenamesOnly" : true}) /],
[@toJSON analyseCMDBProductFiles("dibp", "ics", {"FlattenedFilenamesOnly" : true}) /],
[@toJSON analyseCMDBSegmentFiles("dibp", "ics", "e4", "internalui", {"FlattenedFilenamesOnly" : true}) /],
[@toJSON getCMDBTenantContent("dibp") /],
[@toJSON getCMDBAccountContent("dibp", "dibpnp22") /],
[@toJSON getCMDBProductContent("dibp", "icsbcp") /],
[@toJSON getCMDBSegmentContent("dibp", "icsbcp", "e4", "industry") /],
[@toJSON getCMDBSegmentPlacementContent("dibp", "icsbcp", "e4", "industry", "dibpnp22", "ap-southeast-2") /], --]

[#--assign result = mkdirCMDB("/default/abtcgs/abc/default/def", {"Parents" : true}) --]

[#--assign filterComparisons =
    [
        {
            "Context" : {"Environment" : "e7"},
            "Match" : {"Environment" : "production"},
            "MatchBehaviour" : ONETOONE_FILTER_MATCH_BEHAVIOUR,
            "ExpectedResult" : false
        },
        {
            "Context" : {"Environment" : "e7"},
            "Match" : {"Environment" : ["e7", "e8"]},
            "MatchBehaviour" : ONETOONE_FILTER_MATCH_BEHAVIOUR,
            "ExpectedResult" : true
        },
        {
            "Context" : {"Environment" : "e7"},
            "Match" : {"Segment" : "default"},
            "MatchBehaviour" : ONETOONE_FILTER_MATCH_BEHAVIOUR,
            "ExpectedResult" : false
        },
        {
            "Context" : {"Environment" : "e7"},
            "Match" : {"Any" : ["e7", "e8"]},
            "MatchBehaviour" : ANY_FILTER_MATCH_BEHAVIOUR,
            "ExpectedResult" : true
        },
        {
            "Context" : {"Environment" : "e7"},
            "Match" : {"Any" : ["e4", "e5"]},
            "MatchBehaviour" : ANY_FILTER_MATCH_BEHAVIOUR,
            "ExpectedResult" : false
        }
    ]
]

[#assign filterComparisonResults = [] ]
[#list filterComparisons as filterComparison]
    [#assign matchResult = filterMatch(filterComparison.Context,filterComparison.Match,filterComparison.MatchBehaviour) ]
    [#assign filterComparisonResults +=
        [
            {
                "Outcome" : valueIfTrue("PASS", matchResult = filterComparison.ExpectedResult, "FAIL"),
                "TestCase"  :
                    filterComparison +
                    {
                        "ActualResult" : matchResult
                    }
            }
        ]
    ]
[/#list]
[@toJSON
    {
        "TestSuite" : "filterMatch",
        "TestCases" : filterComparisonResults
    }
/],

[#assign samples =
    [
        {
            "Value" : 1,
            "Qualifiers" : [
                {
                    "Filter" : {"Environment" : "production"},
                    "Value" : 2
                }
            ]
        },
        {
            "Value" : ["a", "b"],
            "Qualifiers" : [
                {
                    "Filter" : {"Environment" : "production"},
                    "Value" : ["c", "d"]
                }
            ]
        },
        {
            "Value" : ["a", "b"],
            "Qualifiers" : [
                {
                    "Filter" : {"Environment" : "production"},
                    "Value" : ["b", "c"],
                    "CombineBehaviour" : APPEND_COMBINE_BEHAVIOUR
                }
            ]
        },
        {
            "Value" : ["a", "b"],
            "Qualifiers" : [
                {
                    "Filter" : {"Environment" : "production"},
                    "Value" : ["b", "c"],
                    "CombineBehaviour" : UNIQUE_COMBINE_BEHAVIOUR
                }
            ]
        },
        {
            "Value" : [
                "a",
                {
                    "Value" : "b",
                    "Qualifiers" : [
                        {
                            "Filter" : {"Environment" : "e7"},
                            "Value" : "b-e7"
                        }
                    ]
                }
            ],
            "Qualifiers" : [
                {
                    "Filter" : {"Environment" : "production"},
                    "Value" : ["b", "c"],
                    "CombineBehaviour" : UNIQUE_COMBINE_BEHAVIOUR
                }
            ]
        },
        {
            "Value" : {
                "a" : 1
            },
            "Qualifiers" : [
                {
                    "Filter" : {"Environment" : "production"},
                    "Value" : {
                        "b" : 1
                    }
                }
            ]
        }
    ]
]

[#assign contexts =
    [
        {"Environment" : "e7"},
        {"Environment" : "production"}
    ]
]

[#assign qualifiedSamples = [] ]
[#list samples as sample]
    [#list contexts as context]
        [#assign qualifiedSamples +=
            [
                {
                    "Sample" : sample,
                    "Context" : context,
                    "Value" : qualifyEntity(sample, context)
                }
            ]
        ]
    [/#list]
[/#list]

[@toJSON
    {
        "TestSuite" : "qualifyEntity",
        "TestCases" : qualifiedSamples
    }
/],


[@toJSON cmdbCache /],
--]

[#assign moduleReferenceConfiguration = [
        {
            "Names" : "Enabled",
            "Description" : "To enable loading the module in this profile",
            "Types" : BOOLEAN_TYPE,
            "Default" : true
        },
        {
            "Names" : "Provider",
            "Description" : "The provider name which offers the module",
            "Type" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "Name",
            "Description" : "The name of the scneario to load",
            "Type" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "Parameters",
            "Description" : "The parameter values to provide to the module",
            "SubObjects" : true,
            "Children" : [
                {
                    "Names" : "Key",
                    "Type" : STRING_TYPE,
                    "Description" : "The key of the parameter",
                    "Mandatory" : true
                },
                {
                    "Names" : "Value",
                    "Type" : ANY_TYPE,
                    "Description" : "The value of the parameter",
                    "Mandatory" : true
                }
            ]
        }
    ]
]

[#assign pluginReferenceConfiguration = [
        {
            "Names" : "Enabled",
            "Description" : "To enable loading the plugin",
            "Types" : BOOLEAN_TYPE,
            "Default" : true
        },
        {
            "Names" : "Required",
            "Types" : BOOLEAN_TYPE,
            "Description" : "Ensure the plugin loads at all times",
            "Default" : false
        },
        {
            "Names" : "Priority",
            "Type" : NUMBER_TYPE,
            "Description" : "The priority order to load plugins - lowest first",
            "Default" : 100
        },
        {
            "Names" : "Name",
            "Type" : STRING_TYPE,
            "Description" : "The id of the plugin to install",
            "Mandatory" : true
        },
        {
            "Names" : "Source",
            "Description" : "Where the plugin for the plugin can be found",
            "Type" : STRING_TYPE,
            "Values" : [ "local", "git" ],
            "Mandatory" : true
        },
        {
            "Names" : "Source:git",
            "Children" : [
                {
                    "Names" : "Url",
                    "Description" : "The Url for the git repository",
                    "Type" : STRING_TYPE
                },
                {
                    "Names" : "Ref",
                    "Description" : "The ref to clone from the repo",
                    "Type" : STRING_TYPE,
                    "Default" : "main"
                },
                {
                    "Names" : "Path",
                    "Description" : "a path within in the repository where the plugin starts",
                    "Type" : STRING_TYPE,
                    "Default" : ""
                }
            ]
        }
    ]
]

[#assign certificateBehaviourConfiguration = [
        {
            "Names" : "External",
            "Types" : BOOLEAN_TYPE
        },
        {
            "Names" : "Wildcard",
            "Types" : BOOLEAN_TYPE
        },
        {
            "Names" : "Qualifiers",
            "Types" : OBJECT_TYPE
        },
        {
            "Names" : "Domain",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "IncludeInDomain",
            "Children" : [
                {
                    "Names" : "Product",
                    "Types" : BOOLEAN_TYPE
                },
                {
                    "Names" : "Environment",
                    "Types" : BOOLEAN_TYPE
                },
                {
                    "Names" : "Segment",
                    "Types" : BOOLEAN_TYPE
                }
            ]
        },
        {
            "Names" : "IncludeInHost",
            "Children" : [
                {
                    "Names" : "Product",
                    "Types" : BOOLEAN_TYPE
                },
                {
                    "Names" : "Environment",
                    "Types" : BOOLEAN_TYPE
                },
                {
                    "Names" : "Segment",
                    "Types" : BOOLEAN_TYPE
                },
                {
                    "Names" : "Tier",
                    "Types" : BOOLEAN_TYPE
                },
                {
                    "Names" : "Component",
                    "Types" : BOOLEAN_TYPE
                },
                {
                    "Names" : "Instance",
                    "Types" : BOOLEAN_TYPE
                },
                {
                    "Names" : "Version",
                    "Types" : BOOLEAN_TYPE
                }
            ]
        },
        {
            "Names" : "HostParts",
            "Types" : ARRAY_OF_STRING_TYPE
        }
    ]
]

[#assign deploymentProfileConfiguration =
    [
        {
            "Names" : "Modes",
            "Description" : "A nested object with the deployment mode name as the root and childs based on component types",
            "Types" : OBJECT_TYPE
        }
    ]
]

[#assign placementProfileConfiguration =
    [
        {
            "Names" : "*",
            "Children"  : [
                {
                    "Names" : "Provider",
                    "Description" : "The provider to use to host the component",
                    "Types" : STRING_TYPE,
                    "Mandatory" : true
                },
                {
                    "Names" : "Region",
                    "Description" : "The id of the region to host the component",
                    "Types" : STRING_TYPE,
                    "Mandatory" : true
                },
                {
                    "Names" : "DeploymentFramework",
                    "Description" : "The deployment framework to use to generate the outputs for deployment",
                    "Types" : STRING_TYPE,
                    "Mandatory" : true
                }
            ]
        }
    ]
]

[#assign attributes =
    [
        {
            "Names" : "Region",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "Domain",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "Modules",
            "SubObjects" : true,
            "Children"  : moduleReferenceConfiguration
        },
        {
            "Names" : "Plugins",
            "SubObjects" : true,
            "Children" : pluginReferenceConfiguration
        },
        {
            "Names" : "Profiles",
            "Children" : [
                {
                    "Names" : "Deployment",
                    "Types" : ARRAY_OF_STRING_TYPE,
                    "Default" : []
                },
                {
                    "Names" : "Policy",
                    "Types" : ARRAY_OF_STRING_TYPE,
                    "Default" : []
                },
                {
                    "Names" : "Placement",
                    "Types" : STRING_TYPE,
                    "Default" : ""
                }
            ]
        },
        {
            "Names" : "CertificateBehaviours",
            "Children" : certificateBehaviourConfiguration
        },
        {
            "Names" : "Builds",
            "Children" : [
                {
                    "Names" : "Data",
                    "Children" : [
                        {
                            "Names" : "Environment",
                            "Types" : STRING_TYPE
                        }
                    ]
                },
                {
                    "Names" : "Code",
                    "Children" : [
                        {
                            "Names" : "Environment",
                            "Types" : STRING_TYPE
                        }
                    ]
                }
            ]
        },
        {
            "Names" : "SES",
            "Children" : [
                {
                    "Names" : "Region",
                    "Types" : STRING_TYPE,
                    "Default" : ""
                }
            ]
        },
        {
            "Names" : "Domain",
            "Types" : STRING_TYPE,
            "Default" : ""
        },
        {
            "Names" : "DeploymentProfiles",
            "SubObjects" : true,
            "Children" : deploymentProfileConfiguration
        },
        {
            "Names" : "PolicyProfiles",
            "SubObjects" : true,
            "Children" : deploymentProfileConfiguration
        },
        {
            "Names" : "PlacementProfiles",
            "SubObjects" : true,
            "Children" : placementProfileConfiguration
        }
    ]
]

[#assign starAttribute =
    [
        {
            "Names" : "*",
            "Description" : "Individual deployment-unit configuration overrides. Attribute must match the DeploymentUnit value.",
            "Types" : OBJECT_TYPE,
            "Children" : [
                {
                    "Names" : "Region",
                    "Description" : "An override of the Region for a single DeploymentUnit.",
                    "Types" : STRING_TYPE
                }
            ]
        }
    ]
]

[#assign objects =
    [
        {
            "Id" : "abcdef",
            "Name" : "abcdef",
            "Domain" : "abcdef",
            "Profiles" : {
                "Deployment" : [ "consolidatelogs", "EncryptionAtRest"]
            },
            "Modules" : {
                "logConsolidation" : {
                    "Name" : "consolidatelogs",
                    "Provider" : "aws",
                    "Parameters" : {
                        "profile" : {
                            "Key" : "deploymentProfile",
                            "Value" : "consolidatelogs"
                        }
                    }
                }
            }
        }
    ]
]

[@toJSON getCompositeObject(attributes, objects) /],
[@toJSON getCompositeObject(attributes + starAttribute, objects) /],

[#--]
[#@toJSON getPlugins({}) /],
[@toJSON
getPluginTree(
        "/",
        {
            "AddEndingWildcard" : false,
            "MinDepth" : 2,
            "MaxDepth" : 2,
            "FilenameGlob" : r"provider.ftl"
        }
    )
/],
[@toJSON
getPluginTree(
        "/",
        {
            "AddEndingWildcard" : false,
            "MinDepth" : 2,
            "MaxDepth" : 2,
            "FilenameGlob" : r"plugin.ftl"
        }
    )
/],
--]
[#assign finish = elapsedTime(start, "Overall") ]
[@toJSON elapsedLog /]
]

