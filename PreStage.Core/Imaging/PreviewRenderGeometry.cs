namespace PreStage.Core.Imaging;

public readonly struct GeometryRect
{
    public double X { get; }
    public double Y { get; }
    public double Width { get; }
    public double Height { get; }

    public double MinX => X;
    public double MinY => Y;
    public double MaxX => X + Width;
    public double MaxY => Y + Height;
    public double MidX => X + Width / 2.0;
    public double MidY => Y + Height / 2.0;

    public GeometryRect(double x, double y, double width, double height)
    {
        X = x;
        Y = y;
        Width = Math.Max(0, width);
        Height = Math.Max(0, height);
    }

    public static GeometryRect FromMinMax(double minX, double minY, double maxX, double maxY)
    {
        return new GeometryRect(minX, minY, maxX - minX, maxY - minY);
    }
}

public readonly struct GeometrySize
{
    public double Width { get; }
    public double Height { get; }

    public GeometrySize(double width, double height)
    {
        Width = width;
        Height = height;
    }
}

public static class PreviewRenderGeometry
{
    public static GeometryRect ImageRect(double aspectRatio, GeometrySize containerSize, double scale)
    {
        if (aspectRatio <= 0 || containerSize.Width <= 0 || containerSize.Height <= 0)
            return new GeometryRect(0, 0, containerSize.Width, containerSize.Height);

        var containerAspect = containerSize.Width / containerSize.Height;
        double fittedWidth, fittedHeight;

        if (aspectRatio > containerAspect)
        {
            fittedWidth = containerSize.Width;
            fittedHeight = containerSize.Width / aspectRatio;
        }
        else
        {
            fittedWidth = containerSize.Height * aspectRatio;
            fittedHeight = containerSize.Height;
        }

        return PixelAlign(new GeometryRect(
            (containerSize.Width - fittedWidth) / 2.0,
            (containerSize.Height - fittedHeight) / 2.0,
            fittedWidth,
            fittedHeight
        ), scale);
    }

    public static GeometryRect CropRect(GeometryRect imageRect, double aspectRatio, double scale)
    {
        if (aspectRatio <= 0 || imageRect.Width <= 0 || imageRect.Height <= 0)
            return new GeometryRect(0, 0, 0, 0);

        var imageAspect = imageRect.Width / imageRect.Height;
        double cropWidth, cropHeight;

        if (aspectRatio > imageAspect)
        {
            cropWidth = imageRect.Width;
            cropHeight = imageRect.Width / aspectRatio;
        }
        else
        {
            cropWidth = imageRect.Height * aspectRatio;
            cropHeight = imageRect.Height;
        }

        return PixelAlign(new GeometryRect(
            imageRect.MidX - cropWidth / 2.0,
            imageRect.MidY - cropHeight / 2.0,
            cropWidth,
            cropHeight
        ), scale);
    }

    public static GeometryRect[] MaskRects(GeometryRect imageRect, GeometryRect cropRect, double scale)
    {
        var image = PixelAlign(imageRect, scale);
        var crop = PixelAlign(cropRect, scale);

        if (image.Width <= 0 || image.Height <= 0 || crop.Width <= 0 || crop.Height <= 0)
            return [];

        var bleed = 1.0 / Math.Max(scale, 1.0);

        var top = new GeometryRect(
            image.MinX - bleed,
            image.MinY - bleed,
            image.Width + bleed * 2.0,
            Math.Max(0, crop.MinY - image.MinY) + bleed * 2.0
        );

        var bottom = new GeometryRect(
            image.MinX - bleed,
            crop.MaxY - bleed,
            image.Width + bleed * 2.0,
            Math.Max(0, image.MaxY - crop.MaxY) + bleed * 2.0
        );

        var left = new GeometryRect(
            image.MinX - bleed,
            crop.MinY - bleed,
            Math.Max(0, crop.MinX - image.MinX) + bleed * 2.0,
            crop.Height + bleed * 2.0
        );

        var right = new GeometryRect(
            crop.MaxX - bleed,
            crop.MinY - bleed,
            Math.Max(0, image.MaxX - crop.MaxX) + bleed * 2.0,
            crop.Height + bleed * 2.0
        );

        return new[] { top, bottom, left, right }
            .Where(r => r.Width > bleed && r.Height > bleed)
            .Select(r => PixelAlign(r, scale))
            .ToArray();
    }

    public static GeometryRect PixelAlign(GeometryRect rect, double scale)
    {
        scale = Math.Max(scale, 1.0);
        var minX = Math.Floor(rect.MinX * scale) / scale;
        var minY = Math.Floor(rect.MinY * scale) / scale;
        var maxX = Math.Ceiling(rect.MaxX * scale) / scale;
        var maxY = Math.Ceiling(rect.MaxY * scale) / scale;
        return GeometryRect.FromMinMax(minX, minY, maxX, maxY);
    }
}
