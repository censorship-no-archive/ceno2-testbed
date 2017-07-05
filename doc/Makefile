.PHONY:		all clean

all:	test-vm.zip

clean:
	rm -f test-vm.zip test-vm.html

test-vm.zip:	test-vm.html images/*.png
	7z a $@ $^

test-vm.html:	test-vm.md
	pandoc -s --toc -t html5 -o $@ $<
