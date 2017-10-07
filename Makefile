TAG := synastry/android-box

build:
	clear
	docker build -t ${TAG} .

run:    
	docker run --rm -it ${TAG}