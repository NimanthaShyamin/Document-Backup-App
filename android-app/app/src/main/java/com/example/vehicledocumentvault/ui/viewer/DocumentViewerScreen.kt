package com.example.vehicledocumentvault.ui.viewer

import android.app.Activity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.vehicledocumentvault.data.DefaultDataRepository
import com.example.vehicledocumentvault.data.DocumentType
import com.example.vehicledocumentvault.data.VehicleDocument

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DocumentViewerScreen(
    documentId: String,
    onBackClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val repository = remember { DefaultDataRepository() }
    val document = remember(documentId) { repository.getDocument(documentId) }

    // Lifecycle-aware Screen Luminance Elevation (100% Brightness)
    DisposableEffect(Unit) {
        val activity = context as? Activity
        val window = activity?.window
        val originalBrightness = window?.attributes?.screenBrightness ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE

        // Elevate screen brightness to 100% (1.0f)
        window?.let {
            val params = it.attributes
            params.screenBrightness = 1.0f
            it.attributes = params
        }

        onDispose {
            // Strictly restore prior system screen brightness
            window?.let {
                val params = it.attributes
                params.screenBrightness = originalBrightness
                it.attributes = params
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = document?.title ?: "Document Viewer",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = "${document?.vehicleRegNo ?: ""} • ${document?.type?.label ?: ""}",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Text(
                            text = "✕",
                            color = Color.White,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF16161A)
                )
            )
        },
        containerColor = Color.Black,
        modifier = modifier
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                // High Luminance Active Indicator
                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = Color(0xFF1E1E24).copy(alpha = 0.9f),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFFFC107).copy(alpha = 0.6f)),
                    modifier = Modifier.padding(bottom = 24.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("☀️", fontSize = 14.sp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "100% Luminance Active (Auto-dim on Exit)",
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                if (document != null) {
                    when (document.type) {
                        DocumentType.FUEL_QR -> FuelQrCard(document)
                        DocumentType.INSURANCE_CARD -> InsuranceCertificateCard(document)
                        DocumentType.REVENUE_LICENSE -> RevenueLicenseCard(document)
                    }
                } else {
                    Text("Document not found", color = Color.White)
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Metadata Details Card
                document?.let { doc ->
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = Color(0xFF1E1E24),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Color.White.copy(alpha = 0.1f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = doc.vehicleRegNo,
                                    color = Color.White,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                    letterSpacing = 1.sp
                                )
                                Text(
                                    text = "VALID: ${doc.expiryDate ?: "N/A"}",
                                    color = Color(0xFF4CAF50),
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            doc.policyNo?.let {
                                Text(
                                    text = "Policy / Reference: $it",
                                    color = Color.White.copy(alpha = 0.8f),
                                    fontSize = 13.sp
                                )
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = "✓",
                                    color = Color(0xFF4CAF50),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = doc.syncStatus,
                                    color = Color(0xFF4CAF50),
                                    fontSize = 11.sp
                                )
                                Spacer(modifier = Modifier.weight(1f))
                                Text(
                                    text = "SHA: ${doc.checksumSha256.take(8)}...",
                                    color = Color.White.copy(alpha = 0.4f),
                                    fontSize = 11.sp,
                                    fontFamily = FontFamily.Monospace
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun FuelQrCard(doc: VehicleDocument) {
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = Color.White,
        shadowElevation = 16.dp,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        Column(
            modifier = Modifier.padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "SRI LANKA NATIONAL FUEL PASS",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.5.sp,
                color = Color(0xFF1E88E5)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = doc.vehicleRegNo,
                fontSize = 24.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 2.sp,
                color = Color.Black
            )
            Spacer(modifier = Modifier.height(16.dp))

            // High-Contrast Vector QR Simulation
            Box(
                modifier = Modifier
                    .size(200.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.White)
                    .border(3.dp, Color.Black, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        QrTargetBox()
                        QrDotGrid()
                        QrTargetBox()
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        QrDotGrid()
                        Text("WP CAB\n1234", fontSize = 11.sp, fontWeight = FontWeight.Black, color = Color.Black, fontFamily = FontFamily.Monospace)
                        QrDotGrid()
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        QrTargetBox()
                        QrDotGrid()
                        Box(modifier = Modifier.size(26.dp).background(Color.Black))
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            doc.quotaRemaining?.let {
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = Color(0xFFE8F5E9)
                ) {
                    Text(
                        text = "QUOTA REMAINING: $it",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF2E7D32),
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "TOKEN: ${doc.policyNo}",
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
                color = Color.Gray
            )
        }
    }
}

@Composable
fun QrTargetBox() {
    Box(
        modifier = Modifier
            .size(42.dp)
            .border(5.dp, Color.Black)
            .padding(7.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        )
    }
}

@Composable
fun QrDotGrid() {
    Column {
        repeat(3) {
            Row {
                repeat(3) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .padding(1.dp)
                            .background(Color.Black)
                    )
                }
            }
        }
    }
}

@Composable
fun InsuranceCertificateCard(doc: VehicleDocument) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = Color(0xFF0D253F),
        border = androidx.compose.foundation.BorderStroke(2.dp, Color(0xFF00C853)),
        shadowElevation = 12.dp,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "SRI LANKA INSURANCE",
                        color = Color(0xFFFFD54F),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 1.sp
                    )
                    Text(
                        text = "MOTOR COMPREHENSIVE CERTIFICATE",
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                Text("🛡️", fontSize = 24.sp)
            }
            HorizontalDivider(color = Color.White.copy(alpha = 0.2f), modifier = Modifier.padding(vertical = 12.dp))
            Text(text = "REGISTRATION: ${doc.vehicleRegNo}", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "POLICY NO: ${doc.policyNo}", color = Color.White.copy(alpha = 0.85f), fontSize = 13.sp)
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "EXPIRATION DATE: ${doc.expiryDate}", color = Color(0xFF00E676), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Authorized Digital Certificate • Stored in AppData Sandbox",
                color = Color.White.copy(alpha = 0.5f),
                fontSize = 10.sp
            )
        }
    }
}

@Composable
fun RevenueLicenseCard(doc: VehicleDocument) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = Color(0xFF2C2416),
        border = androidx.compose.foundation.BorderStroke(2.dp, Color(0xFFFFB300)),
        shadowElevation = 12.dp,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(
                text = "DEMOCRATIC SOCIALIST REPUBLIC OF SRI LANKA",
                color = Color(0xFFFFD54F),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.8.sp
            )
            Text(
                text = "WESTERN PROVINCE MOTOR VEHICLE REVENUE LICENSE",
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Black
            )
            HorizontalDivider(color = Color.White.copy(alpha = 0.2f), modifier = Modifier.padding(vertical = 10.dp))
            Text(text = "VEHICLE NO: ${doc.vehicleRegNo}", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "LICENSE REF: ${doc.policyNo}", color = Color.White.copy(alpha = 0.85f), fontSize = 13.sp)
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "VALID UNTIL: ${doc.expiryDate}", color = Color(0xFFFFCA28), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(10.dp))
            Surface(
                shape = RoundedCornerShape(6.dp),
                color = Color.Black.copy(alpha = 0.4f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "VALIDATED GOVERNMENT MOTOR REVENUE STAMP",
                    color = Color(0xFFFFD54F),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(8.dp)
                )
            }
        }
    }
}
