[#ftl]
[#include "/base.ftl"]
[
[#assign copy =
    cpCMDB(
        "/default/cic/state/cf/integration/default/seg-cert-pmenp01-ap-southeast-2-epilogue-pseduo-stack.json",
        "/default/cic/state/cf/integration/default/cert/default/seg-cert-pmenp01-ap-southeast-2-epilogue-pseduo-stack.json",
        {
            "Recurse" : false,
            "Preserve" : true
        }
    )
]
[@toJSON
    {
        "Copy" : copy
    }
/]
[#--
[#assign delete =
    rmCMDB(
        "/default/cic/state/cf/integration/default/seg-cert-pmenp01-ap-southeast-2-epilogue-pseduo-stack.json",
        {
            "Recurse" : false,
            "Force" : false
        }
    )
]
,[@toJSON
    {
        "Delete" : delete
    }
/]
--]
]
