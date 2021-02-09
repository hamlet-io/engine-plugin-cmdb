[#ftl]

[#-- CMDB engine --]

[#-- Filters
A filter consists of one or more values for each of one or more filter attributes.

{
    "Attribute1" : ["value1", "value2"],
    "Attribute2" : ["value3", "value4", "value5"]
}

Filter comparison is a core mechanism by which processing of the CMDB is controlled.

When filters need to be compared, a "MatchBehaviour" attribute controls the
algorithm used. Algorithms are defined in terms of a

Context Filter - a filter representing current context, and
Match Filter - filter to be checked.

The "any" behaviour requires that at least one value of the "Any" attribute of the
Match Filter needs to match one value in any of the attributes of the Context Filter.

Context Filter
{
    "Environment" : ["prod"]
}

matches

Match Filter
{
    "Any" : ["prod"]
}

The "onetoone" behaviour requires that a value of each attribute of the Match Filter
must match a value of the same named attribute in the Context Filter. The Match
Filter is thus a subset of the Context Filter.

Context Filter
{
    "Product" : ["ics"],
    "Environment" : ["prod"]
    "Segment" : ["default"]
}

matches

Match Filter
{
    "Product" : ["ics"],
    "Environment" : ["prod"],
    "Segment" : ["e7", "default"]
}

but the Context Filter
{
    "Environment" : ["prod"]
    "Segment" : ["default"]
}

does not match.

The "exactonetoone" behaviour uses the same match logic as "onetoone", but
also checks that the Context Filter doesn't have any attributes that
are not included in the Match Filter

--]

[#assign ANY_FILTER_MATCH_BEHAVIOUR = "any"]
[#assign ONETOONE_FILTER_MATCH_BEHAVIOUR = "onetoone"]
[#assign EXACTLY_ONETOONE_FILTER_MATCH_BEHAVIOUR = "exactlyonetoone"]

[#function isValidFilter filter ]
    [#return filter?is_hash]
[/#function]

[#-- Check for a match between a Context Filter and a Match Filter --]
[#function filterMatch contextFilter matchFilter matchBehaviour]

    [#switch matchBehaviour]
        [#case ANY_FILTER_MATCH_BEHAVIOUR]
            [#if !(matchFilter.Any??)]
                [#return true]
            [/#if]
            [#list contextFilter as key, value]
                [#if getArrayIntersection(value, matchFilter.Any)?has_content]
                    [#return true]
                [/#if]
            [/#list]
            [#break]

        [#case ONETOONE_FILTER_MATCH_BEHAVIOUR]
        [#case EXACTLY_ONETOONE_FILTER_MATCH_BEHAVIOUR]
            [#list matchFilter as key,value]
                [#if !(contextFilter[key]?has_content)]
                    [#return false]
                [/#if]
                [#if !getArrayIntersection(contextFilter[key],value)?has_content]
                    [#return false]
                [/#if]
            [/#list]
            [#-- Filters must have the same attributes --]
            [#if
                (matchBehaviour == EXACTLY_ONETOONE_FILTER_MATCH_BEHAVIOUR) &&
                removeObjectAttributes(contextFilter, matchFilter?keys)?has_content]
                [#return false]
            [/#if]
            [#return true]
            [#break]

            [#-- Unknown behaviour --]
            [#default]
            [#return false]
    [/#switch]

    [#-- Filters don't match --]
    [#return false]
[/#function]

[#-- Qualifiers

Qualifiers allow the effective value of an entity to vary based on the value
of a Context Filter.

Each qualifier consists of a Filter, a MatchBehaviour, a Value and a
CombineBehaviour.

Filter - {"Environment" : "prod"}
MatchBehaviour - ONETOONE_FILTER_MATCH_BEHAVIOUR
Value - 50
CombineBehaviour - MERGE_COMBINE_BEHAVIOUR

The Filter acts as a Match Filter for comparison purposes with the provided
Context Filter.

Where the filters match, the qualifier Value is combined with the nominal
value of the entity based on the CombineBehaviour as defined by the
combineEntities() base function.

More than one qualifier may match, in which case the qualifiers are applied to
the nominal value in the order in which the qualifiers are defined.

One or more qualifiers can be added to any entity via a reserved "Qualifiers"
attribute. Where the entity to be qualified is not itself an object, the
desired entity must be wrapped in an object in order that the "Qualifiers" attribute
can be attached. Note thet the  type of the result will be that of the provided
value.

There is a long form and a short form value for Qualifiers.

In the long form, the "Qualifiers" attribute value is a list of qualifier objects.

Each qualifier object must have a "Filter" attribute and a "Value" attribute, as well
as optional "MatchBehaviour" and "DefaultBehaviour" attributes. By default, the
MatchBehaviour is ONETOONE_FILTER_MATCH_BEHAVIOUR and the Combine Behaviour is
MERGE_COMBINE_BEHAVIOUR.

The long form gives full control over the qualification process and the order
in which qualifiers are applied. In the following example, the nominal value is 100,
but 50 will be used assuming the Environment is prod;

{
    "Value" : 100,
    "Qualifiers : [
        {
            "Filter" : {"Environment" : "prod"},
            "MatchBehaviour" : ONETOONE_FILTER_MATCH_BEHAVIOUR,
            "Value" : 50,
            "CombineBehaviour" : MERGE_COMBINE_BEHAVIOUR
        }
    ]
}

In the short form, the "Qualifiers" attribute value is an object.

Each attribute of the attribute value represents a qualifier. The attribute key
is the value of  the "Any" attribute of the Match Filter, the MatchBehaviour is
ANY_FILTER_MATCH_BEHAVIOUR, and the CombineBehaviour is MERGE_COMBINE_BEHAVIOUR.
The attribute value is the value of the attribute.

Because object attribute processing is not ordered, the short form does not provide fine
control in the situation where multiple qualifiers match - effectively they need
to be independent. For consistency, attributes are sorted alphabetically before processing.

The short form is useful for simple situations such as setting variation based
on environment. Assuming environment values are unique, the long form example
could be simplified to

{
  "Value" : 100,
  "Qualifiers" : { "prod" : 50}
}

Equally

{
  "Value" : 100,
  "Qualifiers" : { "prod" : 50, "industry" : 23}
}

is the equivalent of

{
    "Value" : 100,
    "Qualifiers : [
        {
            "Filter" : {"Any" : "prod"},
            "MatchBehaviour" : ANY_FILTER_MATCH_BEHAVIOUR,
            "Value" : 50,
            "CombineBehaviour" : MERGE_COMBINE_BEHAVIOUR
        },
        {
            "Filter" : {"Any" : "industry"},
            "MatchBehaviour" : ANY_FILTER_MATCH_BEHAVIOUR,
            "Value" : 23,
            "CombineBehaviour" : MERGE_COMBINE_BEHAVIOUR
        }
    ]
}

and if both prod and industry matched, the effective value would be 23.

Qualifiers can be nested, so processing is recursive.
--]

[#function qualifyEntity entity contextFilter]

    [#-- Qualify each element of the array --]
    [#if entity?is_sequence ]
        [#local result = [] ]
        [#list entity as element]
            [#local result += [qualifyEntity(element, contextFilter)] ]
        [/#list]
        [#return result]
    [/#if]

    [#-- Only qualifiable entitiy is an object --]
    [#if !entity?is_hash ]
        [#return entity]
    [/#if]


    [#if entity.Qualifiers??]
        [#local qualifiers = entity.Qualifiers]

        [#-- Determine the nominal value --]
        [#if entity.Value??]
            [#local result = entity.Value]
        [#else]
            [#local result = removeObjectAttributes(entity, "Qualifiers")]
        [/#if]

        [#-- Qualify the nominal value --]
        [#local result = qualifyEntity(result, contextFilter) ]

        [#if qualifiers?is_hash ]
            [#local anyFilters = qualifiers?keys?sort]
            [#list anyFilters as anyFilter]
                [#if filterMatch(contextFilter, {"Any" : anyFilter}, ANY_FILTER_MATCH_BEHAVIOUR)]
                    [#local result = combineEntities(result, qualifyEntity(qualifiers[anyFilter], contextFilter), MERGE_COMBINE_BEHAVIOUR) ]
                [/#if]
            [/#list]
        [/#if]

        [#if qualifiers?is_sequence]
            [#list qualifiers as qualifier]
                [#if qualifier.Filter?? && isValidFilter(qualifier.Filter) && qualifier.Value?? ]
                    [#if filterMatch(contextFilter, qualifier.Filter, qualifier.MatchBehaviour!ONETOONE_FILTER_MATCH_BEHAVIOUR) ]
                        [#local result = combineEntities(result, qualifyEntity(qualifier.Value, contextFilter), qualifier.CombineBehaviour!MERGE_COMBINE_BEHAVIOUR) ]
                    [/#if]
                [/#if]
            [/#list]
        [/#if]

    [#else]
        [#-- Qualify attributes --]
        [#local result = {} ]
        [#list entity as key, value]
            [#local result += { key, qualifyEntity(value, contextFilter) } ]
        [/#list]
    [/#if]

    [#return result]
[/#function]
