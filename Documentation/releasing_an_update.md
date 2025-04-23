# Releasing an Update

When you have an update for `gen-ir`, there's a couple things that need to happen:

- Release a version in the `gen-ir` repo
- Update the version(s) in the `homebrew-tap` repo, so brew picks up the update(s)

## Releasing a Gen IR version

As mentioned in the [Branching Model](branching_model.md), features should be merged into the `develop` branch. You should never merge a feature directly to `main`.

To release a new version of `gen-ir`, create a release branch and open a merge request from the release branch (see the [Branching Model](branching_model.md)) to `main`. Allow any automated check, peer reviews, and - when approved - merge the request.  Release version descriptions mm.nn.pp stand for a 2 digit major version, 2 digit minor version, and 2 digit patch version. For example, `0.3.11` is a valid version.

Then, on your local machine:

- Change to `main` and pull the changes
  - `git checkout main && git pull`
- Create the new tag for the release:
  - `git tag -a mm.nn.pp -m "Gen IR version: mm.nn.pp"`
  - `git push --tags`

Then, in the GitHub UI:

- Go to the [Releases](https://github.com/veracode/gen-ir/releases) page
- Click `Draft a new release`
- Set the title to the version name
- From the drop down list, choose your newly created tag from the main branch
- Click the `Generate release notes` button to create a change log
- Ensure `Set as the latest release` is checked
- Click the `Publish` button

A release has been made, congratulations. However there's additional steps for distributing the release via `brew`.

## Distributing a release

Gen IR uses a Homebrew Tap for distribution. In order for the Tap to see the new release, you need to update the [Gen IR Formula](https://github.com/veracode/homebrew-tap/blob/main/Formula/gen-ir.rb).

> Note: You may have to update more than one formula! If you're releasing a new major or minor version, you'll need to ensure versioning of the formula is correct. See the section [Versioning Tap Releases](#versioning-tap-releases) for more information.

First, if you haven't already, checkout the `veracode/homebrew-tap` repo:

```shell
git clone git@github.com:veracode/homebrew-tap.git
```

Then, do the following to increment the formula:

- Create a new branch - replacing `<version>` with the released version:
  - `git checkout -b gen_ir_<version>`
- Update the `gen-ir.rb` formula:
  - Change `url.tag`'s value to the tag's name
  - Change `url.revision` to the commit hash pointed to by the tag
- Open a merge request with _only these changes!_
  - If you have more than one commit, or change more than this single file - homebrews automation will refuse to merge the request.
- When the `test-bot` check passes, add the `pr-pull` label to the request
- Automation will make the new release

Users can now run `brew update && brew upgrade gen-ir` to update to the latest version.

## Versioning Tap Releases

It is likely that you will need to do One More Thing, which is to ensure the formula is versioned correctly.

Gen IR has the following policy on versions:

- Gen IR will maintain formulae for one version behind _and_ any current prerelease versions
- Any versioned formulae **must** use `keg_only :versioned_formula`
  - This means brew will _only_ install into the Cellar, and will not link into the brew prefix
- Gen IR _will not_ maintain formulae for patch versions

So, if you have released a new major or minor version you should:

- Create a new versioned formula for the previous release to yours
- Remove any now-deprecated formula(e)

### Creating Versioned Formulae

Using the history of the `homebrew-tap` find the version of the Gen IR formula you're looking for, then copy the file to the `Formula` folder renaming it like so: `gen-ir@<version>`

Edit the file to:

- change the name of the class to add the version, for example version 0.3.11 becomes: `GenIrAT0311`.
- add the `keg_only :versioned_formula` tag after the `bottle`.

> Note: it is a good idea to run `brew style Formulae/gen-ir@<version>.rb` before you push the commit! Brew is _very_ particular about the layout of a formula and the test-bot will fail if your key isn't in the right spot.
