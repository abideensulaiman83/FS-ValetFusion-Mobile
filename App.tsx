import React from 'react';
import { SafeAreaView, StatusBar, StyleSheet, Text, View } from 'react-native';

export default function App() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar barStyle="dark-content" />
      <View style={styles.container}>
        <Text style={styles.eyebrow}>Valet operations on the go</Text>
        <Text style={styles.title}>FS ValetFusion Mobile</Text>
        <Text style={styles.subtitle}>
          A lightweight mobile entry point for checking in vehicles, tracking parking status,
          and coordinating retrieval requests.
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#f4f7fb',
  },
  container: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
    gap: 12,
  },
  eyebrow: {
    color: '#44607c',
    fontSize: 14,
    fontWeight: '600',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },
  title: {
    color: '#132238',
    fontSize: 32,
    fontWeight: '700',
  },
  subtitle: {
    color: '#4b5f77',
    fontSize: 16,
    lineHeight: 24,
  },
});
