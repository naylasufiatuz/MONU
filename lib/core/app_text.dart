import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monu/core/app_colors.dart';

/// Semua gaya teks. Judul pakai Playfair Display, isi pakai Poppins.
class AppText {
  AppText._();

  // Judul besar (serif)
  static TextStyle get display => GoogleFonts.playfairDisplay(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.forest,
        height: 1.15,
      );

  // Judul besar versi miring (serif italic)
  static TextStyle get displayItalic => GoogleFonts.playfairDisplay(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: AppColors.forest,
        height: 1.15,
      );

  // Judul halaman / bagian
  static TextStyle get headline => GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.25,
      );

  // Judul kartu
  static TextStyle get title => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.3,
      );

  // Teks isi
  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.45,
      );

  // Teks isi versi lembut
  static TextStyle get bodySoft => GoogleFonts.poppins(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.inkSoft,
        height: 1.45,
      );

  // Teks kecil
  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: AppColors.inkSoft,
        height: 1.4,
      );

  // Label tebal kecil
  static TextStyle get label => GoogleFonts.poppins(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.3,
      );

  // Teks tombol
  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.2,
      );

  // Angka besar (nilai sensor)
  static TextStyle get value => GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.1,
      );
}