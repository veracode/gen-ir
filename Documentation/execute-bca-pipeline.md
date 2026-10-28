# ***Veracode Only***
# Execute the BCA Pipeline on a Gen-IR Release

## One Time Setup
1. Check the value of CI_XCODE_SUPPORTED variable in https://gitlab.laputa.veracode.io/static/simple-code-scanners/BitcodeAnalyzer/-/settings/ci_cd#js-cicd-variables-settings (currently 27.1) - this is the Xcode version you need to use for tests building. If you need to test with older Xcode versions - let me know and I’ll another CI/CD variable specifically for that purpose.

2. If you don’t have the following installed, do this: 
```
    brew update && brew upgrade
    brew install coreutils pyenv pyenv-virtualenv xcodesorg/made/xcodes jq
    brew install cocoapods
```  

3. Setup your Python environment for BCA testing   
Edit your ~/.zshrc file (or the bash equivalent) and add the following.
```
    export PYENV_ROOT=$HOME/.pyenv
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
```

4. Set up Python venv for bca-testing:
```
    pyenv install 3.12.0
    pyenv virtualenv 3.12.0 bca
    pyenv activate bca
    pip install --upgrade pip awscli
    python -m pip intstall boto3’
```  

## Build and Run a Test
1. Make sure you have the target Xcode version (27.1) installed and selected, and all the components downloaded (xcodebuild -downloadAllPlatforms)

2. Make sure that the python bca environment is activated
```
    pyenv activate bca
```

3. Make sure xcodes installed. If not, you may be able to get by with the following:
```
    mkdir -p ~/bin && printf '#!/bin/sh\n[ "$1 $2" = "select -p" ] && exec xcode-select -p\nexec false\n' > ~/bin/xcodes && chmod +x ~/bin/xcodes && export PATH="$HOME/bin:$PATH"
```

4. Make sure you have the following repositories cloned: 
    Recommended directory structure:
    - ROOT-of-your-choosing
        - bca
            - bca-projects (git clone git@gitlab.laputa.veracode.io:static/tools/bca-projects.git)
            - bca-testing (git clone git@gitlab.laputa.veracode.io:static/tools/bca-testing.git)
            - BitcodeAnalyzer (Optionallly git clone git@gitlab.laputa.veracode.io:static/simple-code-scanners/BitcodeAnalyzer.git)
            - Tests (Created after running the generate.py script)

5. Build the candidate gen-ir from source, make sure that “which gen-ir” resolves to the gen-ir build you want to test.
    - change directory to ROOT-of-your-choosing/bca
    - See lines 350-359 then build the tests : https://gitlab.laputa.veracode.io/static/simple-code-scanners/BitcodeAnalyzer/-/blob/develop/.gitlab-ci.yml?ref_type=heads#L350
```
Build the tests: python <path-to-bca-testing>/bca_testing/generate.py --bca-projects <path-to-bca-projects> --output Tests
```

6. Package and upload:
```
tar -czvf genir-<GENIR_VERSION>-bca-test-apps-bc-27.1.tar.gz Tests
aws s3 cp "genir-<GENIR_VERSION>-bca-test-apps-bc-27.1.tar.gz" s3://staticengine-ci-build-artifacts/bitcode-analyzer/genir-test-apps/ --no-progress --profile staticengine-ci
```

7. Run the pipeline: trigger a pipeline with GENIR_VERSION set to the same value you used 'Building a test' Step 6.

### History
    - https://veracode.atlassian.net/browse/SSAST-10768
