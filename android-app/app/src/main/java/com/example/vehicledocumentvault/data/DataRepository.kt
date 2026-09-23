package com.example.vehicledocumentvault.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

enum class DocumentType(val label: String) {
    FUEL_QR("National Fuel Pass"),
    INSURANCE_CARD("Motor Insurance Certificate"),
    REVENUE_LICENSE("Vehicle Revenue License")
}

data class VehicleDocument(
    val id: String,
    val type: DocumentType,
    val title: String,
    val vehicleRegNo: String,
    val policyNo: String? = null,
    val expiryDate: String? = null,
    val isExpired: Boolean = false,
    val syncStatus: String = "Synced (drive.appdata)",
    val quotaRemaining: String? = null,
    val checksumSha256: String = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
)

interface DataRepository {
    val documents: Flow<List<VehicleDocument>>
    fun getDocument(id: String): VehicleDocument?
}

class DefaultDataRepository : DataRepository {
    private val sampleDocs = listOf(
        VehicleDocument(
            id = "fuel_qr_001",
            type = DocumentType.FUEL_QR,
            title = "National Fuel Pass (Petrol 92)",
            vehicleRegNo = "WP CAB-1234",
            policyNo = "FP-77892019-LK",
            expiryDate = "Perpetual / Active",
            quotaRemaining = "18.5L / 20.0L",
            syncStatus = "Synced (drive.appdata)",
            checksumSha256 = "9b1deb4d3b7d4bad9bdd2b0d7b3dcb6d8839210aa3949bbcf12498"
        ),
        VehicleDocument(
            id = "ins_002",
            type = DocumentType.INSURANCE_CARD,
            title = "Motor Insurance (Comprehensive)",
            vehicleRegNo = "WP CAB-1234",
            policyNo = "POL-88921-LK-2026",
            expiryDate = "2026-10-15",
            syncStatus = "Synced (drive.appdata)",
            checksumSha256 = "c2a938fe10bb42119934eef103a8830188992010ab949439210bc"
        ),
        VehicleDocument(
            id = "rev_003",
            type = DocumentType.REVENUE_LICENSE,
            title = "Annual Revenue License 2026/2027",
            vehicleRegNo = "WP CAB-1234",
            policyNo = "REV-WP-2026-904128",
            expiryDate = "2026-12-31",
            syncStatus = "Synced (drive.appdata)",
            checksumSha256 = "f38102bbac930198471209384bbad300188492010ac9492104921"
        )
    )

    override val documents: Flow<List<VehicleDocument>> = flow {
        emit(sampleDocs)
    }

    override fun getDocument(id: String): VehicleDocument? {
        return sampleDocs.find { it.id == id }
    }
}
