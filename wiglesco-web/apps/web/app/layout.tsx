import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Wiglesco - 3D Parallax & Wigglegram Creator",
  description: "Create stunning 3D wiggle stereograms, wigglegrams, and depth parallax loops from a single photo using AI.",
  keywords: [
    "Wiglesco",
    "stereogram",
    "wigglegram",
    "d3d",
    "nishika",
    "n8000",
    "3d photo",
    "3d parallax",
    "depth map",
    "wiggle 3d",
    "parallax loop"
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
