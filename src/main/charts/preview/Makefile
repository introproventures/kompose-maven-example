OS := $(shell uname)

preview: 
	helm init --client-only
	helm repo add chartmuseum http://jenkins-x-chartmuseum:8080
	helm repo add chartmuseum https://chartmuseum.build.cd.jenkins-x.io
	helm dependency build
	helm lint