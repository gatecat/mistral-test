DEVICE?=5CSEBA6U23I7
QSF=de10nano.qsf

%.json: %.v
	yosys -p "synth_intel_alm -nobram -nolutram -top top -nodsp; write_json $@" $^

%.rbf: %.json ${QSF}
	nextpnr-mistral --parallel-refine --device ${DEVICE} --json $< --qsf ${QSF} --compress-rbf --router router2 --rbf $@

# This target program over USB gadget RNDIS, see the SD card image linked in an issue
%.prog: %.rbf
	scp -O $< root@192.168.69.1:/lib/firmware/bitstream.rbf
	ssh root@192.168.69.1 reload-fpga

clean:
	rm -f *.json *.rbf

.PRECIOUS: %.json %.rbf
