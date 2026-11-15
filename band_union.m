function selected=band_union(f,bands)
selected=false(numel(f),1);
for r=1:size(bands,1)
    selected=selected|(f>=bands(r,1)&f<=bands(r,2));
end
end
