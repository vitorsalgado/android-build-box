TAG := vitorsalgado/android-build-box

build:
	clear
	docker build -t ${TAG} .

run:    
	docker run --rm -it ${TAG}