# Hamlet Engine Plugin - CMDB

This is a plugin for the Hamlet engine which provides configuration database (cmdb) support including
- analysis
- access
- migrations
- reports

It provides one provider

- **cmdb** - which implements the actual processing


## Implementation

In addition to general analysis and access routines that can be consumed by any plugin, two entrances are provided.

They should be run from the directory where the cmdbs repos has been checked out (which should also contain the `root.json` file that marks the root of the cmdb directory structure).

```$GENERATION_DIR/createTemplate.sh -i mock -e {entrance} -p cmdb -o {output-dir} -y "actions={ "|" separated list,{other name=value parameters}"```

- **cmdbinfo** - provides information reports about the available cmdbs

  Available parameters are
  - cmdbs - a `|` separated list of cmdbs to be processed via the `cmdbs` action
  - actions - controls the output produced
    - `inputs` - show the layer values being used
    - `lists` - show the layer values available in the cmdb
    - `context` - show the context filter being used to qualify content
    - `files` - show the files found in the cmdb
    - `content` - show the content available at the various layers
    - `qualified` - show the content qualified with the context filter
    - `cache` - show the contents of the cmdb cache - mainly used to see the results of the cmdb directory analysis
    - `cmdbs` - to show the cmdbs discovered (filtered by any content of the `cmdbs` parameter)

  - filters - a `|` separated list of flags that control the level of output produced
    - `SuppressContent` - do not include file content in the match objects
    - `FlattenedFilenamesOnly` - only list filenames rather than the match objects

  The context is constructed from the following layer values, with the layer value treated as a `|` separated list (to permit name and id to be provided - name is expected to be the first value and
  is what is shown via the "`inputs` action)
  - tenant (if none provided, and only one is found in the provided cmdbs, then the found one is used)
  - account
  - product
  - environment
  - segment

- **cmdbmigration** - performs cmdb upgrades and cleanups, replacing the existing bash process

  Available parameters
  - cmdbs - a `|` separated list of cmdbs to be processed
  - actions - controls the output produced
    - `upgrade` - perform cmdb upgrade
    - `cleanup` - perform cmdb cleanup
  - `upgrade` - version to upgrade to
  - `cleanup` - version to cleanup to
  - `dryrun` - don't actually perform the migration but show what would be done if it were

## Installation

1. Clone this repository into your hamlet workspace
2. Add the path to the cloned location to the `GENERATION_PLUGINS_DIR` env var

    ```bash
    export GENERATION_PLUGINS_DIR="$(pwd);${GENERATION_PLUGINS_DIR}
    ```

3. The plugin will now be available as a provider to hamlet and can be included via `-p cmdb`.

## Testing

`test_snippets.sh` contains some example command lines used to test the provider both via `createTemplate.sh` and directly via `freemarker-wrapper.jar`. `test.ftl` contains a simple freemarker script to exercise the functions provided by the plugin.