MISTRAL_DIR?=${HOME}/mistral
DEVICE?=5CSEBA6U23I7
QSF=de10nano.qsf

%.json: %.v
	yosys -p "synth_intel_alm -top top -nodsp -nolutram -nobram; write_json $@" $^

%.rbf: %.json ${QSF}
	nextpnr-mistral --mistral ${MISTRAL_DIR} --device ${DEVICE} --json $< --qsf ${QSF} --rbf $@

# This target program over USB gadget RNDIS, see the SD card image linked in an issue
%.prog: %.rbf
	scp $< root@192.168.69.1:/lib/firmware/bitstream.rbf
	ssh root@192.168.69.1 reload-fpga

clean:
	rm -f *.json *.rbf

.PRECIOUS: *.json *.rbf
