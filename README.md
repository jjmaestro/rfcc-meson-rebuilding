# `rfcc-meson-rebuilding`

Example Bazel repo to repro `rules_foreign_cc` unexpectedly rebuilding a
`meson` target.

## TL;DR

This seems to be a known issue, see https://github.com/bazelbuild/rules_python/blob/727ab43107fb0b2d528140f609b873670a5c6c26/python/private/python_repository.bzl#L187-L195.

The fix: https://github.com/bazel-contrib/rules_foreign_cc/pull/1343
```diff
diff --git a/toolchains/built_toolchains.bzl b/toolchains/built_toolchains.bzl
index e517c56..5abe0ed 100644
--- a/toolchains/built_toolchains.bzl
+++ b/toolchains/built_toolchains.bzl
@@ -20,7 +20,9 @@ exports_files(["meson.py"])
 
 filegroup(
     name = "runtime",
-    srcs = glob(["mesonbuild/**"]),
+    # NOTE: excluding __pycache__ is important to avoid rebuilding due to pyc
+    # files, see https://github.com/bazel-contrib/rules_foreign_cc/issues/1342
+    srcs = glob(["mesonbuild/**"], exclude = ["**/__pycache__/*"]),
     visibility = ["//visibility:public"],
 )
 """
```

<details>
<summary>OLD NOTES (for future reference)</summary>

## Reproducing the (unexpected) rebuilding

<details open>
<summary>./repro.sh bazel_build_all</summary>

```sh
rfcc-rebuilding % ./repro.sh bazel_build_all
INFO: Starting clean (this may take a while). Consider using --async if the clean takes more than several minutes.

bazel build \
    --verbose_failures \
    --verbose_explanations \
    --sandbox_debug \
    --explain=logs/rebuilding/explain-1.log \
    --execution_log_json_file=logs/rebuilding/execution_log-1.json \
    //example:meson

Starting local Bazel server and connecting to it...
INFO: Analyzed target //example:meson (110 packages loaded, 10974 targets configured).
INFO: Found 1 target...
INFO: Writing explanation of rebuilds to 'logs/rebuilding/explain-1.log'
Target //example:meson up-to-date:
  bazel-bin/example/meson/include
  bazel-bin/example/meson/bin/example
INFO: Elapsed time: 93.823s, Critical Path: 87.88s
INFO: 14 processes: 11 internal, 3 darwin-sandbox.
INFO: Build completed successfully, 14 total actions
Loading: 0 packages loaded

bazel build \
    --verbose_failures \
    --verbose_explanations \
    --sandbox_debug \
    --explain=logs/rebuilding/explain-2.log \
    --execution_log_json_file=logs/rebuilding/execution_log-2.json \
    //example:meson

INFO: Analyzed target //example:meson (1 packages loaded, 360 targets configured).
INFO: Found 1 target...
INFO: Writing explanation of rebuilds to 'logs/rebuilding/explain-2.log'
Target //example:meson up-to-date:
  bazel-bin/example/meson/include
  bazel-bin/example/meson/bin/example
INFO: Elapsed time: 3.806s, Critical Path: 3.61s
INFO: 5 processes: 4 internal, 1 darwin-sandbox.
INFO: Build completed successfully, 5 total actions
Loading: 0 packages loaded

bazel build \
    --verbose_failures \
    --verbose_explanations \
    --sandbox_debug \
    --explain=logs/rebuilding/explain-3.log \
    --execution_log_json_file=logs/rebuilding/execution_log-3.json \
    //example:meson

INFO: Analyzed target //example:meson (0 packages loaded, 0 targets configured).
INFO: Found 1 target...
INFO: Writing explanation of rebuilds to 'logs/rebuilding/explain-3.log'
Target //example:meson up-to-date:
  bazel-bin/example/meson/include
  bazel-bin/example/meson/bin/example
INFO: Elapsed time: 0.126s, Critical Path: 0.00s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
Loading: 0 packages loaded
```
</details>

The second build should not trigger a rebuild, but it does:
```sh
wc -l logs/rebuilding/explain-*
      15 logs/rebuilding/explain-1.log
    2536 logs/rebuilding/explain-2.log
       2 logs/rebuilding/explain-3.log
    2553 total
```

Looking at `logs/with_rebuilding/explain-2.log`:
```sh
rfcc-rebuilding % head -n 15 logs/with_rebuilding/explain-2.log; echo -e '\n(...)\n'; tail logs/with_rebuilding/explain-2.log
Build options: --verbose_failures --verbose_explanations --explain=logs/with_rebuilding/explain-2.log
Executing action 'BazelWorkspaceStatusAction stable-status.txt': unconditional execution is requested.
Executing action 'Writing repo mapping manifest for @@rules_foreign_cc~//toolchains/private:meson_tool [for tool]': action command has changed.
Executing action 'Creating source manifest for @@rules_foreign_cc~//toolchains/private:meson_tool [for tool]': action command has changed.
New action: GUID: 07459553-a3d0-4d37-9d78-18ed942470f4
remotableSourceManifestActions: false
runfiles: conflictPolicy: IGNORE
legacyExternalRunfiles: true
suffix: _main
symlinks: <empty>
rootSymlinks: <empty>
artifacts: order: COMPILE_ORDER (fingerprinting considers internal nested set structure, which is not reflected in values reported below)
size: 2515
  ../rules_foreign_cc~~tools~meson_src/mesonbuild/__init__.py, /private/var/tmp/_bazel_jjmaestro/3b2939be8b8bd5ef003fc854f70419e8/external/rules_foreign_cc~~tools~meson_src/mesonbuild/__init__.py, 
  ../rules_foreign_cc~~tools~meson_src/mesonbuild/__pycache__/__init__.cpython-311.pyc, /private/var/tmp/_bazel_jjmaestro/3b2939be8b8bd5ef003fc854f70419e8/external/rules_foreign_cc~~tools~meson_src/mesonbuild/__pycache__/__init__.cpython-311.pyc,

(...)

  ../rules_python~~python~python_3_11_aarch64-apple-darwin/share/man/man1/python3.1, /private/var/tmp/_bazel_jjmaestro/3b2939be8b8bd5ef003fc854f70419e8/external/rules_python~~python~python_3_11_aarch64-apple-darwin/share/man/man1/python3.1,
  ../rules_python~~python~python_3_11_aarch64-apple-darwin/share/man/man1/python3.11.1, /private/var/tmp/_bazel_jjmaestro/3b2939be8b8bd5ef003fc854f70419e8/external/rules_python~~python~python_3_11_aarch64-apple-darwin/share/man/man1/python3.11.1,

emptyFilesSupplier: com.google.devtools.build.lib.rules.python.PythonUtils$GetInitPyFiles

    Platform: PlatformInfo(@@platforms//host:host, constraints=<[@@platforms//cpu:aarch64, @@platforms//os:osx]>)
    Exec Properties: {}
.
Executing action 'Creating runfiles tree bazel-out/darwin_arm64-opt-exec-ST-d57f47055a04/bin/external/rules_foreign_cc~/toolchains/private/meson_tool.runfiles [for tool]': One of the files has changed.
Executing action 'Foreign Cc - Meson: Building meson': One of the files has changed.
```

Something in `rules_foreign_cc` `meson` or `rules_python` is causing the rebuild? :-?

## Comparing inputs

```sh
% ./repro.sh compare_rebuilding_inputs
logs/rebuilding/execution_log-1.json
"@@rules_foreign_cc~//toolchains/private:make_tool"
"@@rules_foreign_cc~//toolchains/private:pkgconfig_tool_default"
"//example:meson"

logs/rebuilding/execution_log-2.json
"//example:meson"

diff inputs...
```

And, sure enough, it's a bunch of `.pyc` files!
```diff
--- logs/rebuilding/execution_log-1.example_meson.inputs.json   2024-12-13 21:41:48
+++ logs/rebuilding/execution_log-2.example_meson.inputs.json   2024-12-13 21:41:48
@@ -76,6 +76,296 @@
   },
   {
     "digest": {
+      "hash": "effc79e8e942e54cdf89245c9ca9175aba32feea5532775c52eb77df102da882",
+      "hashFunctionName": "SHA-256",
+      "sizeBytes": "241"
+    },
+    "isTool": true,
+    "path": "bazel-out/darwin_arm64-opt-exec-ST-d57f47055a04/bin/external/rules_foreign_cc~/toolchains/private/meson_tool.runfiles/_main/external/rules_foreign_cc~~tools~meson_src/mesonbuild/__pycache__/__init__.cpython-311.pyc",
+    "symlinkTargetPath": ""
+  },
+  {
+    "digest": {
+      "hash": "da6ea1648b2abdac811276c639f6907acee2304f99b9685ab938c3920564b4ba",
+      "hashFunctionName": "SHA-256",
+      "sizeBytes": "2635"
+    },

(...)

+    "digest": {
+      "hash": "45a17de4e9ea33246d4cb7e37f6c17287cd88a309d9a366a9646ac57fc527a85",
+      "hashFunctionName": "SHA-256",
+      "sizeBytes": "59653"
+    },
+    "isTool": true,
+    "path": "external/rules_foreign_cc~~tools~meson_src/mesonbuild/wrap/__pycache__/wrap.cpython-311.pyc",
+    "symlinkTargetPath": ""
+  },
+  {
+    "digest": {
+      "hash": "7b81e3b9469a169f9cb75176b60b15dd2dc1ffecef2d5d4d6cfdc68eed42ee0f",
+      "hashFunctionName": "SHA-256",
+      "sizeBytes": "13737"
+    },
+    "isTool": true,
+    "path": "external/rules_foreign_cc~~tools~meson_src/mesonbuild/wrap/__pycache__/wraptool.cpython-311.pyc",
     "symlinkTargetPath": ""
   },
   {
```

Looks like it's all about files that are somehow added / "appearing":
```
rfcc-rebuilding % grep '^- ' "logs/rebuilding/execution_log-example_meson.inputs.diff" | wc -l
       0

rfcc-rebuilding % grep '^+ ' "logs/rebuilding/execution_log-example_meson.inputs.diff" | wc -l
    3600
```

How / where are these coming from?

Also, another weird thing is that it seems to be python `3.11`:
```
rfcc-rebuilding % grep '^+ ' "logs/rebuilding/execution_log-example_meson.inputs.diff" |
    grep pyc | grep -v '311\.pyc'
```

but `rules_foreign_cc` sets the python toolchain to `3.9`... and I've also
tried changing the registered toolchain to `3.13`:
```diff
% git diff
diff --git a/MODULE.bazel b/MODULE.bazel
index d800594..7fe0720 100644
--- a/MODULE.bazel
+++ b/MODULE.bazel
@@ -23,8 +23,8 @@ bazel_dep(name = "bazel_ci_rules", version = "1.0.0", dev_dependency = True)
 bazel_dep(name = "rules_cc", version = "0.0.9", dev_dependency = True)
 
 python = use_extension("@rules_python//python/extensions:python.bzl", "python")
-python.toolchain(python_version = "3.9")
-use_repo(python, "python_3_9")
+python.toolchain(python_version = "3.13")
+use_repo(python, "python_3_13")
 
 tools = use_extension("@rules_foreign_cc//foreign_cc:extensions.bzl", "tools")
 use_repo(
@@ -46,6 +46,6 @@ register_toolchains(
     "@rules_foreign_cc_framework_toolchains//:all",
     "@cmake_3.23.2_toolchains//:all",
     "@ninja_1.12.1_toolchains//:all",
-    "@python_3_9//:all",
+    "@python_3_13//:all",
     "@rules_foreign_cc//toolchains:all",
 )
```

Trying to find the `3.11` interpreter, sure enough:
```
rfcc-rebuilding % ls bazel-rfcc-meson-rebuilding/external | grep python
rules_python~
rules_python~~python~python_3_11_aarch64-apple-darwin
rules_python~~python~python_3_13
rules_python~~python~pythons_hub

rfcc-rebuilding % ls -l bazel-rfcc-meson-rebuilding/external/rules_python~~python~python_3_11_aarch64-apple-darwin/
total 16
-rwxr-xr-x@  1 jjmaestro  wheel  448 14 Dec 15:02 BUILD.bazel
-rw-r--r--@  1 jjmaestro  wheel    0 14 Dec 15:02 REPO.bazel
-rwxr-xr-x@  1 jjmaestro  wheel  100 14 Dec 15:02 STANDALONE_INTERPRETER
-rw-r--r--@  1 jjmaestro  wheel    0 14 Dec 15:02 WORKSPACE
drwxr-xr-x@ 16 jjmaestro  wheel  512 14 Dec 15:02 bin
drwxr-xr-x@  3 jjmaestro  wheel   96 14 Dec 15:02 include
dr-xr-xr-x@ 10 jjmaestro  wheel  320 14 Dec 15:02 lib
lrwxr-xr-x@  1 jjmaestro  wheel  141 14 Dec 15:02 python
drwxr-xr-x@  3 jjmaestro  wheel   96 14 Dec 15:02 share
```

So, `3.11`seems to be the `STANDALONE_INTERPRETER`... but I thought that
interpreter was only used to bootstrap `rules_python` and, after registering a
Python toolchain, the registered toolchain would be used :-?

I've also tried a whole bunch of "`rules_python` dogscience" but the results
are always the same, (1) the `pyc` files appear, forcing a rebuild, and (2)
they are always `311.pyc`:
```diff
diff --git a/MODULE.bazel b/MODULE.bazel
index d800594..7fe0720 100644
--- a/MODULE.bazel
+++ b/MODULE.bazel
@@ -9,7 +9,7 @@ module(
 bazel_dep(name = "bazel_features", version = "1.15.0")
 bazel_dep(name = "bazel_skylib", version = "1.3.0")
 bazel_dep(name = "platforms", version = "0.0.5")
-bazel_dep(name = "rules_python", version = "0.23.1")
+bazel_dep(name = "rules_python", version = "1.0.0")
 bazel_dep(name = "rules_shell", version = "0.3.0")
 
 # Dev dependencies
@@ -23,8 +23,8 @@ bazel_dep(name = "bazel_ci_rules", version = "1.0.0", dev_dependency = True)
 bazel_dep(name = "rules_cc", version = "0.0.9", dev_dependency = True)
 
 python = use_extension("@rules_python//python/extensions:python.bzl", "python")
-python.toolchain(python_version = "3.9")
-use_repo(python, "python_3_9")
+python.toolchain(python_version = "3.13")
+use_repo(python, "python_3_13")
 
 tools = use_extension("@rules_foreign_cc//foreign_cc:extensions.bzl", "tools")
 use_repo(
@@ -46,6 +46,6 @@ register_toolchains(
     "@rules_foreign_cc_framework_toolchains//:all",
     "@cmake_3.23.2_toolchains//:all",
     "@ninja_1.12.1_toolchains//:all",
-    "@python_3_9//:all",
+    "@python_3_13//:all",
     "@rules_foreign_cc//toolchains:all",
 )
diff --git a/foreign_cc/built_tools/meson_build.bzl b/foreign_cc/built_tools/meson_build.bzl
index 696f5ae..a2f165e 100644
--- a/foreign_cc/built_tools/meson_build.bzl
+++ b/foreign_cc/built_tools/meson_build.bzl
@@ -8,7 +8,11 @@ def meson_tool(name, main, data, requirements = [], **kwargs):
         srcs = [main],
         data = data,
         deps = requirements,
-        python_version = "PY3",
         main = main,
+        precompile = "enabled",
+        precompile_invalidation_mode = "unchecked_hash",
+        precompile_source_retention = "omit_source",
+        pyc_collection = "disabled",
+        stamp = 0,
         **kwargs
     )
diff --git a/toolchains/built_toolchains.bzl b/toolchains/built_toolchains.bzl
index e517c56..aebdc23 100644
--- a/toolchains/built_toolchains.bzl
+++ b/toolchains/built_toolchains.bzl
@@ -20,7 +20,7 @@ exports_files(["meson.py"])
 
 filegroup(
     name = "runtime",
-    srcs = glob(["mesonbuild/**"]),
+    srcs = glob(["mesonbuild/**"], exclude = ["__pycache__/**"]),
     visibility = ["//visibility:public"],
 )
 """
```
</details>
