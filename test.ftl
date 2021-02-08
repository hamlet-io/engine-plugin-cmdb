[#ftl]
[#assign start = .now]
[#assign timer = start]

[#include "base.ftl" ]
[#include "./cmdb/cmdb.ftl"]
[#include "./cmdb/engine.ftl"]

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

[@analyseCMDBStructure /]
[#assign timer = elapsedTime(timer, "Analyse CMDB") ]

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

[#assign filterComparisons =
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
            "ExpectedResult" : true
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
[#assign finish = elapsedTime(start, "Overall") ]
[@toJSON elapsedLog /]
]

