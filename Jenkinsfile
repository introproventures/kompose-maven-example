pipeline {
    agent {
      label "jenkins-maven"
    }
    environment {
      ORG               = "igdianov"
      APP_NAME          = "kompose-maven-example"
      CHARTMUSEUM_CREDS = credentials("jenkins-x-chartmuseum")
    }
    stages {
      stage("Init") {
        steps {
          container("maven") {
            sh "helm init --client-only"
			sh "helm repo add chartmuseum http://jenkins-x-chartmuseum:8080"
			sh "helm repo add chartmuseum https://chartmuseum.build.cd.jenkins-x.io"

            sh "mvn dependency:resolve dependency:resolve-plugins"
          }        
        }
      }
      stage("CI Build and push snapshot") {
        when {
          branch "PR-*"
        }
        environment {
          PREVIEW_VERSION = "0.0.0-SNAPSHOT-$BRANCH_NAME-$BUILD_NUMBER"
          PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
          HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        }
        steps {
          container("maven") {
            sh "mvn versions:set -DnewVersion=$PREVIEW_VERSION"
            sh "mvn install dockerfile:push -Ddockerfile.repository=\$JENKINS_X_DOCKER_REGISTRY_SERVICE_HOST:\$JENKINS_X_DOCKER_REGISTRY_SERVICE_PORT/$ORG/$APP_NAME -Ddockerfile.tag=\$PREVIEW_VERSION"

            sh "jx step validate --min-jx-version 1.2.36"
            sh "jx step post build --image \$JENKINS_X_DOCKER_REGISTRY_SERVICE_HOST:\$JENKINS_X_DOCKER_REGISTRY_SERVICE_PORT/$ORG/$APP_NAME:$PREVIEW_VERSION"
            
            // make preview
            sh "cd ./target/charts/preview && ls -a && jx preview --app \$APP_NAME --dir ../../.."
          }
        }
      }
      stage("Set Release Version") {
        when {
          branch "master"
        }
        steps {
          container("maven") {
            // ensure we're not on a detached head
            sh "git checkout master"
            sh "git config --global credential.helper store"
            sh "jx step validate --min-jx-version 1.1.73"
            sh "jx step git credentials"
            
            // so we can retrieve the version in later steps
            sh "echo \$(jx-release-version) > VERSION"

            sh "echo Set Release Version: \$(cat VERSION)"
            sh "mvn versions:set -DnewVersion=\$(cat VERSION)"
          }
        }
      }
      stage("Make Tag Release") {
        when {
          branch "master"
        }
        steps {
            container("maven") {
	            // make commit
	            sh "git add --all"
	            
	            // if first release then no version update is performed
	            sh "git commit -m \"release \$(cat VERSION)\" --allow-empty"
	            sh "git tag -fa v\$(cat VERSION) -m \"Release version \$(cat VERSION)\""
	            sh "git push origin v\$(cat VERSION)"
            }
        }
      }
      stage("Build Release") {
        when {
          branch "master"
        }
        steps {
          container("maven") {
            sh "mvn clean deploy dockerfile:push -Ddockerfile.repository=\$JENKINS_X_DOCKER_REGISTRY_SERVICE_HOST:\$JENKINS_X_DOCKER_REGISTRY_SERVICE_PORT/$ORG/$APP_NAME -Ddockerfile.tag=\$(cat VERSION)"

            sh "jx step validate --min-jx-version 1.2.36"
            sh "jx step post build --image \$JENKINS_X_DOCKER_REGISTRY_SERVICE_HOST:\$JENKINS_X_DOCKER_REGISTRY_SERVICE_PORT/$ORG/$APP_NAME:\$(cat VERSION)"
          }
        }
      }
      stage("Promote to Environments") {
        when {
          branch "master"
        }
        steps {
            container("maven") {
              sh "jx step changelog --version v\$(cat VERSION)"

              // release the helm chart
              withCredentials([usernameColonPassword(credentialsId: "jenkins-x-chartmuseum", variable: "USERPASS")]) {
                sh "export TAG=\$(cat VERSION) && cd ./target/charts/$APP_NAME && ls -a && curl --fail -u $USERPASS --data-binary \"@$APP_NAME-\$TAG.tgz\" \$CHART_REPO/api/charts"
              }              

              // promote through all 'Auto' promotion Environments
              sh "jx promote -b --all-auto --timeout 1h --version \$(cat VERSION)"
            }
        }
      }
    }
    post {
        success {
            cleanWs()
        }
        failure {
            input """Pipeline failed. 
We will keep the build pod around to help you diagnose any failures. 

Select Proceed or Abort to terminate the build pod"""
        }
    }
  }
