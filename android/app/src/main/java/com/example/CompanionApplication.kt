package com.example

import android.app.Application
import com.example.di.AppContainer
import com.example.di.DefaultAppContainer

class CompanionApplication : Application() {
    lateinit var appContainer: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        appContainer = DefaultAppContainer(this)
    }
}
