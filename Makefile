all:debug

release: Sources/icaltoday/icaltoday.swift
	xcrun swift build -c release --arch arm64 --arch x86_64

debug:
	xcrun swift build 


