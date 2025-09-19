pipeline {
    agent any

    environment {

        // Project info
        APP_NAME = 'warranty-management-fe'
        RELEASE = '1'
        GITHUB_URL = 'https://github.com/NguyenThinhNe/SWP391_FrontEnd.git'
        GIT_MANIFEST_FILE = "https://github.com/NguyenThinhNe/FE_Manifest.git"

        // Sonar Scanner info
        SCANNER_HOME = tool 'sonarqube-scanner'
        SONAR_HOST_URL = 'https://sonarqube.fleeforezz.site'

        // Docker info
        DOCKER_USER = 'fleeforezz'
        DOCKER_IMAGE_NAME = "${DOCKER_USER}" + '/' + "${APP_NAME}"
        DOCKER_IMAGE_VERSION = "${RELEASE}.${env.BUILD_NUMBER}"

        // Environment-specific variable
        ENVIRONMENT = "${env.BRANCH_NAME == 'master' ? 'production' : 'development'}"
        K8S_NAMESPACE = "${env.BRANCH_NAME == 'master' ? 'prod' : 'dev'}"
    }

    stages {
        stage('Environment Info') {
            steps {
                script {
                    echo "======================================="
                    echo "Branch: ${env.BRANCH_NAME}"
                    echo "Environment: ${ENVIRONMENT}"
                    echo "Kubernetes Namespace: ${K8S_NAMESPACE}"
                    echo "Build Trigger: ${env.BUILD_CAUSE}"
                    echo "======================================="
                }
            }
        }

        stage('Clean up WorkSpace') {
            steps {
                echo "#====================== Clean up WorkSpace ======================#"
                cleanWs()
            }
        }

        stage('Git Checkout') {
            steps {
                echo '#====================== Git Checkout for (${env.BRANCH_NAME}) ======================#'
                checkout scm: [$class: 'GitSCM',
                    branches: [[name: "${env.BRANCH_NAME}"]],
                    userRemoteConfigs: [[
                        credentialsId: 'github-credentials',
                        url: "${GITHUB_URL}"
                    ]]
                ]
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    echo "#====================== Sonar Scan for (${env.BRANCH_NAME}) ======================#"
                    sh """
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=${APP_NAME}-${env.BRANCH_NAME} \
                        -Dsonar.projectName="${APP_NAME} (${ENVIRONMENT})" \
                        -Dsonar.host.url=${SONAR_HOST_URL}
                    """
                }
            }
        }

        // stage('Quality Gate') {
        //     steps {
        //         script {
        //             timeout(time: 3, unit: 'MINUTES') {
        //                 def qg = waitForQualityGate()

        //                 if (qg.status != 'OK') {
        //                     if (env.BRANCH_NAME == 'prod') {
        //                         error "Quality Gate failed for PROD: ${qg.status}. Deployment blocked!"
        //                     } else {
        //                         echo "Quality Gate failed for DEV: ${qg.status}. Continuing with warnings..."
        //                         currentBuild.result = 'UNSTABLE'
        //                     }
        //                 }
        //             }
        //         }
        //     }
        // }

        stage('Node Build') {
            steps {
                echo "#====================== Node install and build ======================#"
                script {
                    if (env.BRANCH_NAME == 'master') {
                        sh "npm install"
                        sh "npm run build:prod"
                    } else {
                        sh "npm install"
                        sh "npm run build:dev"
                    }
                }
            }
        }

        // stage('OWASP DP-SCAN') {
        //     steps {
        //         dependencyCheck additionalArguments: '', nvdCredentialsId: 'NVD-API', odcInstallation: 'owasp-dp-check'
        //     }
        // }

        stage('Security Scans') {
            parallel {
                stage('Trivy Filesystem Scan') {
                    steps {
                        echo "#====================== Trivy Filesystem scan ======================#"
                        sh """
                            trivy fs . --format json --output trivyfs.json
                            trivy fs . --format table --output trivy.txt
                            cat trivy.txt
                        """
                        archiveArtifacts artifacts: 'trivy.*', allowEmptyArchive: true
                    }
                }

                stage('NPM Audit') {
                    steps {
                        echo "#====================== NPM Security Audit ======================#"
                        sh """
                            npm audit --audit-level=high --json > npm-audit.json || true
                            npm audit --audit-level=high || true
                        """
                        archiveArtifacts artifacts: 'npm-audit.json', allowEmptyArchive: true
                    }
                }
            }
        }

        

        stage('Docker Build') {
            steps {
                script {
                    echo "#====================== Docker Build ======================#"
                    // Dockerfile var
                    def dockerfile = "." // Add custom Dockerfile name ex: ./PathToDockerfile/PathToDockerfile/DevDockerfile
                    def contextDir = "." // Path to DockerFile ex: ./PathToDockerfile/PathToDockerfile

                    // Build Docker image with custom Dockerfile
                    // def dockerImage = docker.build(
                    //     "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}",
                    //     "-f ${dockerfile} ${contextDir}"
                    // )

                    // Build Docker image with normal Dockerfile
                    def dockerImage = docker.build(
                        "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}"
                    )

                    // Set IMAGE_TAGGED dynamically
                    if (env.BRANCH_NAME == 'master') {
                        env.IMAGE_TAGGED = "${DOCKER_IMAGE_NAME}:latest"
                        dockerImage.tag('latest')  // ✅ Tag latest
                    } else {
                        env.IMAGE_TAGGED = "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}-beta"
                        dockerImage.tag("${DOCKER_IMAGE_VERSION}-beta")  // ✅ Tag beta
                    }
                }
            }
        }

        stage('Docker Test') {
            steps {
                echo "#====================== Docker Test ======================#"
                script {
                    def containerName = "test-${APP_NAME}-${env.BUILD_NUMBER}"
                    def testPort = env.BRANCH_NAME == 'master' ? '3000' : '5173'

                    // Test docker in background
                    sh """
                        # Start container in background
                        docker run -d --name ${containerName} \
                        -p ${testPort}:${testPort} ${env.IMAGE_TAGGED}

                        # Wait for container to start
                        sleep 10

                        # Test if the container respone
                        curl -f http://localhost:${testPort} || exit 1

                        # Clean up
                        #docker stop ${containerName}
                        #docker rm ${containerName}
                    """
                }
            }
        }

        stage('Trivy Docker Image Scan') {
            steps {
                echo "#====================== Trivy Docker Image Scan ======================#"
                script {
                    def securityLevel = env.BRANCH_NAME == 'master' ? 'HIGH,CRITICAL' : 'CRITICAL'

                    sh "trivy image --no-progress --exit-code 1 --format json --severity UNKNOWN,HIGH,CRITICAL ${env.IMAGE_TAGGED} > trivyimage.txt || true"

                    sh """
                        trivy image --no-progress --format json \
                            --severity ${securityLevel} \
                            --output trivyimage.json ${env.IMAGE_TAGGED}

                        trivy image --no-progress --format table \
                            --severity ${securityLevel} \
                            --output trivyimage.txt ${env.IMAGE_TAGGED}
                        
                        cat trivyimage.txt
                    """
                }
                archiveArtifacts artifacts: 'trivyimage.txt', allowEmptyArchive: true
            }
        }

        stage('Push to registry') {
            steps {
                echo "#====================== Push Docker Image to DockerHub Registry ======================#"
                script {
                    withDockerRegistry(credentialsId: 'Docker_Login', toolName: 'Docker', url: 'https://index.docker.io/v1/') {
                        def image = docker.image("${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}")

                        if (env.BRANCH_NAME == 'master') {
                            echo "Pushing production images..."
                            image.push('latest')
                            image.push("v${DOCKER_IMAGE_VERSION}")
                        } else {
                            echo "Pushing development images..."
                            image.push("${DOCKER_IMAGE_VERSION}-beta")
                            image.push('dev-latest')
                        }
                    }
                }
            }
        }

        stage("Checkout Manifest Repository"){
            steps{
                script {
                    echo "#====================== Checkout Manifest Repository ======================#"
                    def currentBranch = env.BRANCH_NAME == 'master' ? 'prod' : 'dev'
                    
                    sh 'rm -rf manifest'
                    sh "git clone -b ${currentBranch} ${GIT_MANIFEST_FILE} manifest"
                }
            }
        }

        stage("Update Manifest Files") {
            steps {
                echo "#====================== Update Kubernetes Manifest Files ======================#"
                dir('manifest') {
                    script {
                        sh """
                            echo "Updating ${APP_NAME} image to ${env.IMAGE_TAGGED} in manifest.yml"
                            sed -i 's|image: .*${APP_NAME}:.*|image: ${env.IMAGE_TAGGED}|g' manifest.yml
                            echo "Updated manifest.yml:"
                            cat manifest.yml | grep -A 2 -B 2 "image:"
                        """
                    }
                }
            }
        }

        stage("Commit and Push Manifest Changes") {
            steps {
                echo "#====================== Commit and Push Manifest Changes ======================#"
                dir('manifest') {
                    script {
                        sshagent(['guests-ssh']) {
                            def currentBranch = env.BRANCH_NAME == 'master' ? 'prod' : 'dev'
                            
                            sh """
                            # Add Github to known hosts
                            mkdir -p ~/.ssh
                            ssh-keyscan github.com >> ~/.ssh/known_hosts

                            # Configure git
                            git config --global user.email "fleeforezz@gmail.com"
                            git config --global user.name "fleeforezz"
                                
                            # Add changes
                            git add .
                                
                            # Commit with descriptive message
                            git commit -m "🚀 Update ${APP_NAME} to ${env.IMAGE_TAGGED} [skip ci]" || echo "No changes to commit"
                                
                            # Use SSH
                            git remote set-url origin git@github.com:NguyenThinhNe/FE_Manifest.git

                            # Push changes
                            git push origin ${currentBranch}
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                def buildStatus = currentBuild.result ?: 'SUCCESS'
                def statusIcon = buildStatus == 'SUCCESS' ? '✅' : '❌'
                def environment = env.BRANCH_NAME == 'master' ? 'PRODUCTION' : 'DEVELOPMENT'

                emailext(
                    attachLog: true,
                    subject: "${statusIcon} ${buildStatus} - ${environment} Deployment - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>${statusIcon} ${environment} Deployment ${buildStatus}</h2>

                        <table border="1" cellpadding="5" cellspacing="0">
                            <tr><td><b>Project:</b></td><td>${env.JOB_NAME}</td></tr>
                            <tr><td><b>Build Number:</b></td><td>${env.BUILD_NUMBER}</td></tr>
                            <tr><td><b>Environment:</b></td><td>${environment}</td></tr>
                            <tr><td><b>Branch:</b></td><td>${env.BRANCH_NAME}</td></tr>
                            <tr><td><b>Docker Image:</b></td><td>${env.IMAGE_TAGGED}</td></tr>
                            <tr><td><b>Kubernetes Namespace:</b></td><td>${K8S_NAMESPACE}</td></tr>
                            <tr><td><b>Build URL:</b></td><td><a href="${env.BUILD_URL}">${env.BUILD_URL}</a></td></tr>
                        </table>

                        <br/>
                        <p><b>Artifacts:</b> Security scans and test reports are attached.</p>
                            
                        ${env.CHANGE_ID ? "<p><b>Pull Request:</b> #${env.CHANGE_ID} by ${env.CHANGE_AUTHOR}</p>" : ""}
                    """,
                    to: 'fleeforezz@gmail.com',
                    attachmentsPattern: 'trivyfs.*,trivyimage.*,npm-audit.json'
                )
            }
        }

        success {
            echo "🎉 Pipeline completed successfully!"
        }

        failure {
            echo "💥 Pipeline failed. Check the logs for details."
        }

        cleanup {
            sh """
                echo "🧹 Cleaning up Docker resources..."
                docker rmi ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION} || true
                docker rmi ${env.IMAGE_TAGGED} || true
                docker system prune -f || true
                echo "✅ Cleanup completed"
            """
        }
    }
}
