package com.example.vehicledocumentvault

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable data object Main : NavKey

@Serializable data class DocumentViewer(val documentId: String) : NavKey
