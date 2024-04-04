all: debug

SWIFT_FLAGS :=

# Check for the availability of EKAuthorizationStatus.fullAccess and set SWIFT_FLAGS accordingly
check_evkit:
    @if swift probes/check_ekauth.swift 2>/dev/null ; then \
        echo "EKAuthorizationStatus.fullAccess is available"; \
        SWIFT_FLAGS=""; \
    else \
        echo "EKAuthorizationStatus.fullAccess is not available"; \
        SWIFT_FLAGS="-Xswiftc -DOLD_EVKIT"; \
    fi

# Export SWIFT_FLAGS so it's available in all targets
export SWIFT_FLAGS

# Build the debug version
debug: check_evkit
	xcrun swift build $$SWIFT_FLAGS
	@echo "Built for debugging. See ./.build/debug/icaltoday"

# Build the release version
release: check_evkit Sources/icaltoday/icaltoday.swift
	xcrun swift build -c release --arch arm64 --arch x86_64 $$SWIFT_FLAGS
	@echo "Built for release. See .build/apple/Products/Release/icaltoday"

# Run tests with the SWIFT_FLAGS
test: check_evkit
	xcrun swift test $$SWIFT_FLAGS



