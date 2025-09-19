pipeline {
    agent any

    environment {

        // Project info
        APP_NAME = 'warranty-management-fe'
        RELEASE = '1'
        GITHUB_URL = 'https://github.com/TonnyCoder/SWP391_FrontEnd.git'
        GIT_MANIFEST_FILE = "https://github.com/fleeforezz/Manifest.git"

        // Sonar Scanner info
        SCANNER_HOME = tool 'sonarqube-scanner'
        SONAR_HOST_URL = 'https://sonarqube.fleeforezz.site'

        // Docker info
        DOCKER_USER = 'fleeforezz'
        DOCKER_IMAGE_NAME = "${DOCKER_USER}" + '/' + "${APP_NAME}"
        DOCKER_IMAGE_VERSION = "${RELEASE}.${env.BUILD_NUMBER}"
    }

    stages {
        stage('Clean up WorkSpace') {
            steps {
                echo "#====================== Clean up WorkSpace ======================#"
                cleanWs()
            }
        }

        stage('Git Checkout') {
            steps {
                echo '#====================== Git Checkout ======================#'
                git branch: 'dev', url: "${GITHUB_URL}"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    echo "#====================== Sonar Scan ======================#"
                    sh "$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=warranty-management-fe -Dsonar.host.url=${SONAR_HOST_URL}"
                }
            }
        }

        // stage('Quality Gate') {
        //     steps {
        //         script {
        //             timeout(time: 2, unit: 'MINUTES') {
        //                 waitForQualityGate abortPipeline: false
        //             }
        //         }
        //     }
        // }

        stage('Node Build') {
            steps {
                echo "#====================== Node install and build ======================#"
                sh "npm install"
                sh "npm run build"
            }
        }

        // stage('OWASP DP-SCAN') {
        //     steps {
        //         dependencyCheck additionalArguments: '', nvdCredentialsId: 'NVD-API', odcInstallation: 'owasp-dp-check'
        //     }
        // }

        stage('Trivy Filesystem Scan') {
            steps {
                echo "#====================== Trivy Filesystem scan ======================#"
                sh 'trivy fs . > trivyfs.txt'
                sh 'cat trivyfs.txt'
                archiveArtifacts artifacts: 'trivyimage.txt', allowEmptyArchive: true
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
                    if (env.BRANCH_NAME == 'main') {
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
                    // Test docker in background
                    sh """
                        # Start container in background
                        docker run -d --name test-warranty-management-fe-${env.BUILD_NUMBER} \
                        -p 5173:5173 ${env.IMAGE_TAGGED}

                        # Wait for container to start
                        sleep 10

                        # Test if the container respone
                        curl -f http://localhost:5173 || exit 1

                        # Clean up
                        #docker stop test-warranty-management-fe-${env.BUILD_NUMBER}
                        #docker rm test-warranty-management-fe-${env.BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Trivy Docker Image Scan') {
            steps {
                echo "#====================== Trivy Docker Image Scan ======================#"
                sh "trivy image --no-progress --exit-code 1 --format json --severity UNKNOWN,HIGH,CRITICAL ${env.IMAGE_TAGGED} > trivyimage.txt || true"

                sh 'cat trivyimage.txt'
                archiveArtifacts artifacts: 'trivyimage.txt', allowEmptyArchive: true
            }
        }

        stage('Push to registry') {
            steps {
                echo "#====================== Push Docker Image to DockerHub Registry ======================#"
                script {
                    withDockerRegistry(credentialsId: 'Docker_Login', toolName: 'Docker', url: 'https://index.docker.io/v1/') {
                        def image = docker.image("${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}")

                        if (env.BRANCH_NAME == 'main') {
                            image.tag('latest')
                        } else {
                            image.push("${DOCKER_IMAGE_VERSION}-beta")
                        }
                    }
                }
            }
        }

        stage("Checkout Manifest Repository"){
            steps{
                echo "#====================== Checkout Manifest Repository ======================#"
                sh 'rm -rf manifest'
                sh 'git clone -b warranty-management ${GIT_MANIFEST_FILE} manifest'
            }
        }

        stage("Update Manifest Files") {
            steps {
                echo "#====================== Update Kubernetes Manifest Files ======================#"
                dir('manifest') {
                    script {
                        sh """
                            echo "Updating ${APP_NAME} image to ${env.IMAGE_TAGGED}"
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
                            git remote set-url origin git@github.com:fleeforezz/Manifest.git

                            # Push changes
                            git push origin melville
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            emailext(
                attachLog: true,
                subject: "${currentBuild.result} - ${env.JOB_NAME} Build #${env.BUILD_NUMBER}",
                body: """
                    <b>Project:</b> ${env.JOB_NAME}<br/>
                    <b>Build Number:</b> ${env.BUILD_NUMBER}<br/>
                    <b>Docker Image Tag:</b> ${env.IMAGE_TAGGED}<br/>
                    <b>URL:</b> <a href="${env.BUILD_URL}">${env.BUILD_URL}</a><br/>
                    <b>Manifest Repository:</b> ${GIT_MANIFEST_FILE}<br/>
                """,
                to: 'fleeforezz@gmail.com',
                attachmentsPattern: 'trivyfs.txt,trivyimage.txt'
            )
        }

        cleanup {
            sh """
                docker rmi ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION} || true
                docker rmi ${env.IMAGE_TAGGED} || true
                docker system prune -f || true
            """
        }
    }
}
