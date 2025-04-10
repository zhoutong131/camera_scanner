// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#include "texture_handler.h"
#include <cassert>
#include <ZXing/ReadBarcode.h>
namespace camera_scanner {

    TextureHandler::~TextureHandler() {
        // Texture might still be processed while destructor is called.
        // Lock mutex for safe destruction
        const std::lock_guard<std::mutex> lock(buffer_mutex_);
        if (texture_registrar_ && texture_id_ > 0) {
            texture_registrar_->UnregisterTexture(texture_id_);
        }
        texture_id_ = -1;
        texture_ = nullptr;
        texture_registrar_ = nullptr;
    }

    int64_t TextureHandler::RegisterTexture() {
        if (!texture_registrar_) {
            return -1;
        }

        // Create flutter desktop pixelbuffer texture;
        texture_ =
            std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
                [this](size_t width,
                    size_t height) -> const FlutterDesktopPixelBuffer* {
                        return this->ConvertPixelBufferForFlutter(width, height);
                }));

        texture_id_ = texture_registrar_->RegisterTexture(texture_.get());
        return texture_id_;
    }

    //// 定义结构体
    //struct ImgResult {
    //    uint8_t* data;
    //    int width;
    //    int height;
    //};
    //ImgResult CropAndConvertToGray(
    //    uint8_t* bgrx,
    //    int width,
    //    int height,
    //    float rate
    //) {
    //    // 参数检查
    //    if (bgrx == nullptr || rate <= 0.0f || rate > 1.0f || width <= 0 || height <= 0) {
    //        return { nullptr,0 ,0 };
    //    }

    //    // 1. 计算截取区域的尺寸
    //    const int crop_width = static_cast<int>(width * rate);
    //    const int crop_height = crop_width;

    //    // 2. 确保起始坐标非负
    //    const int start_x = std::max((width - crop_width) / 2, 0);
    //    const int start_y = std::max((height - crop_height) / 2, 0);

    //    // 3. 计算有效截取尺寸（确保不越界）
    //    const int valid_crop_width = std::min(crop_width, width - start_x);
    //    const int valid_crop_height = std::min(crop_height, height - start_y);

    //    // 检查有效尺寸合法性
    //    if (valid_crop_width <= 0 || valid_crop_height <= 0) {
    //        return { nullptr,valid_crop_width ,valid_crop_height };
    //    }

    //    // 4. 分配内存并检查
    //    uint8_t* gray = new (std::nothrow) uint8_t[valid_crop_width * valid_crop_height];
    //    if (!gray) return { nullptr,valid_crop_width ,valid_crop_height };

    //    // 5. 优化像素处理
    //    for (int y = 0; y < valid_crop_height; ++y) {
    //        const uint8_t* src_row = bgrx + ((start_y + y) * width + start_x) * 4;
    //        uint8_t* gray_row = gray + y * valid_crop_width;

    //        for (int x = 0; x < valid_crop_width; ++x) {
    //            const uint8_t B = src_row[x * 4];
    //            const uint8_t G = src_row[x * 4 + 1];
    //            const uint8_t R = src_row[x * 4 + 2];

    //            // 精确四舍五入计算灰度值
    //            gray_row[x] = static_cast<uint8_t>(0.114f * B + 0.587f * G + 0.299f * R + 0.5f);
    //        }
    //    }
    //    return { gray,valid_crop_width ,valid_crop_height };;
    //}
    // 定义图片结果结构体
    struct ImgResult {
        std::unique_ptr<uint8_t[]> data;
        int width;
        int height;
    };

    // 裁剪并转换为灰度图的函数
    ImgResult CropAndConvertToGray(
        uint8_t* xrgb,
        int width,
        int height,
        float rate
    ) {
        // 参数检查
        if (xrgb == nullptr || rate <= 0.0f || rate > 1.0f || width <= 0 || height <= 0) {
            return { nullptr, 0, 0 };
        }

        // 1. 计算截取区域的尺寸
        const int crop_width = static_cast<int>(width * rate);
        const int crop_height = crop_width;

        // 2. 确保起始坐标非负
        const int start_x = std::max((width - crop_width) / 2, 0);
        const int start_y = std::max((height - crop_height) / 2, 0);

        // 3. 计算有效截取尺寸（确保不越界）
        const int valid_crop_width = std::min(crop_width, width - start_x);
        const int valid_crop_height = std::min(crop_height, height - start_y);

        // 检查有效尺寸合法性
        if (valid_crop_width <= 0 || valid_crop_height <= 0) {
            return { nullptr, valid_crop_width, valid_crop_height };
        }

        // 4. 分配内存
        auto gray = std::make_unique<uint8_t[]>(valid_crop_width * valid_crop_height);

        // 5. 优化像素处理
        for (int y = 0; y < valid_crop_height; ++y) {
            const uint8_t* src_row = xrgb + ((start_y + y) * width + start_x) * 4;
            uint8_t* gray_row = gray.get() + y * valid_crop_width;

            for (int x = 0; x < valid_crop_width; ++x) {
                // 注意通道顺序：X R G B
                const uint8_t R = src_row[x * 4 + 1];
                const uint8_t G = src_row[x * 4 + 2];
                const uint8_t B = src_row[x * 4 + 3];

                // 精确四舍五入计算灰度值
                gray_row[x] = static_cast<uint8_t>(0.114f * B + 0.587f * G + 0.299f * R + 0.5f);
            }
        }

        return { std::move(gray), valid_crop_width, valid_crop_height };
    }
    bool TextureHandler::UpdateBuffer(uint8_t* data, uint32_t data_length) {
        // Scoped lock guard.
        
        {
            const std::lock_guard<std::mutex> lock(buffer_mutex_);
            if (!TextureRegistered()) {
                return false;
            }

            if (source_buffer_.size() != data_length) {
                // Update source buffer size.
                source_buffer_.resize(data_length);
            }
            std::copy(data, data + data_length, source_buffer_.data());
            std::thread([this]() {
                ImgResult info = CropAndConvertToGray(source_buffer_.data(), this->preview_frame_width_, this->preview_frame_height_, this->ratio);
                if (info.data != nullptr) {
                    auto zimage = ZXing::ImageView(info.data.get(), info.width, info.height, ZXing::ImageFormat::Lum);
                    //delete[] info.data;
                    auto options = ZXing::ReaderOptions().setFormats(ZXing::BarcodeFormat::QRCode);     //设置解码类型 Any 全部
                    auto barcodes = ZXing::ReadBarcodes(zimage, options);
                    for (const auto& barcode : barcodes) {
                        capture_controller_listener_->OnScanCode(barcode.text());
                    }
                }
                //delete[] data;
            }).detach();
        }
        OnBufferUpdated();
        return true;
    };

    // Marks texture frame available after buffer is updated.
    void TextureHandler::OnBufferUpdated() {
        if (TextureRegistered()) {
            texture_registrar_->MarkTextureFrameAvailable(texture_id_);
        }
    }

    const FlutterDesktopPixelBuffer* TextureHandler::ConvertPixelBufferForFlutter(
        size_t target_width, size_t target_height) {
        // TODO: optimize image processing size by adjusting capture size
        // dynamically to match target_width and target_height.
        // If target size changes, create new media type for preview and set new
        // target framesize to MF_MT_FRAME_SIZE attribute.
        // Size should be kept inside requested resolution preset.
        // Update output media type with IMFCaptureSink2::SetOutputMediaType method
        // call and implement IMFCaptureEngineOnSampleCallback2::OnSynchronizedEvent
        // to detect size changes.

        // Lock buffer mutex to protect texture processing
        std::unique_lock<std::mutex> buffer_lock(buffer_mutex_);
        if (!TextureRegistered()) {
            return nullptr;
        }

        const uint32_t bytes_per_pixel = 4;
        const uint32_t pixels_total = preview_frame_width_ * preview_frame_height_;
        const uint32_t data_size = pixels_total * bytes_per_pixel;
        if (data_size > 0 && source_buffer_.size() == data_size) {
            if (dest_buffer_.size() != data_size) {
                dest_buffer_.resize(data_size);
            }

            // Map buffers to structs for easier conversion.
            MFVideoFormatRGB32Pixel* src =
                reinterpret_cast<MFVideoFormatRGB32Pixel*>(source_buffer_.data());
            FlutterDesktopPixel* dst =
                reinterpret_cast<FlutterDesktopPixel*>(dest_buffer_.data());

            for (uint32_t y = 0; y < preview_frame_height_; y++) {
                for (uint32_t x = 0; x < preview_frame_width_; x++) {
                    uint32_t sp = (y * preview_frame_width_) + x;
                    if (mirror_preview_) {
                        // Software mirror mode.
                        // IMFCapturePreviewSink also has the SetMirrorState setting,
                        // but if enabled, samples will not be processed.

                        // Calculates mirrored pixel position.
                        uint32_t tp =
                            (y * preview_frame_width_) + ((preview_frame_width_ - 1) - x);
                        dst[tp].r = src[sp].r;
                        dst[tp].g = src[sp].g;
                        dst[tp].b = src[sp].b;
                        dst[tp].a = 255;
                    }
                    else {
                        dst[sp].r = src[sp].r;
                        dst[sp].g = src[sp].g;
                        dst[sp].b = src[sp].b;
                        dst[sp].a = 255;
                    }
                }
            }

            if (!flutter_desktop_pixel_buffer_) {
                flutter_desktop_pixel_buffer_ =
                    std::make_unique<FlutterDesktopPixelBuffer>();

                // Unlocks mutex after texture is processed.
                flutter_desktop_pixel_buffer_->release_callback =
                    [](void* release_context) {
                    auto mutex = reinterpret_cast<std::mutex*>(release_context);
                    mutex->unlock();
                    };
            }

            flutter_desktop_pixel_buffer_->buffer = dest_buffer_.data();
            flutter_desktop_pixel_buffer_->width = preview_frame_width_;
            flutter_desktop_pixel_buffer_->height = preview_frame_height_;

            // Releases unique_lock and set mutex pointer for release context.
            flutter_desktop_pixel_buffer_->release_context = buffer_lock.release();

            return flutter_desktop_pixel_buffer_.get();
        }
        return nullptr;
    }

}  // namespace camera_scanner
