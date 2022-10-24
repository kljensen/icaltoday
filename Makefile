all:debug

release: Sources/icaltoday/icaltoday.swift
	xcrun swift build -c release --arch arm64 --arch x86_64
	echo "Built for release. See .build/apple/Products/Release/icaltoday"

debug:
	xcrun swift build 
	echo "Built for debugging. See ./.build/debug/icaltoday"


