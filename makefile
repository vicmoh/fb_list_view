git:
	dart format ./lib/
	flutter analyze
	git add -A
	git commit -m '$(m)'
	git push

new:
	git branch $(version); git checkout $(version); git push --set-upstream origin $(version); git checkout master;

	
