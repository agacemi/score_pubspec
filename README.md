A Dart script to score libraries referenced in a given pubspec.lock. it generates an html file with lots of information about the lib. The rating is highlighted by colors (green, orange, red, black).

The main goal is to get a general overview of the libraries used by the application and to assess the maintenance risk of using a given library.

## Quick Start 🚀

### Installing 🧑‍💻

```sh
dart pub global activate score_pubspec
```

### Commands ✨

The command requires to define env variable GITHUB_TOKEN thats represents token to make request on gitlab api. 
### `score_pubspec`


#### Usage

```sh
# score pubspec.lock in the current directory
score_pubspec 

# score the given file with path argment
score_pubspec --path 'path-to-pubspec.lock'


# score only direct dependencies and skip the transitive ones
score_pubspec --only-direct-spec

```